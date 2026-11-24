import { createServer } from 'node:http';
import { isIP } from 'node:net';

// One HTTP process serves the functions of backend/src/index.js outside
// Cloud Functions (Fly.io, branch dev-banco-fly). Each callable keeps its own
// handler from firebase-functions: request format, token check, CORS, errors
// and the answer stay those of Cloud Functions. This file only gives the
// handlers the small part of the Express interface they use.

// Cloud Functions accepts requests of up to 10 MB.
export const MAX_BODY_BYTES = 10 * 1024 * 1024;
const NAME = /^[A-Za-z][A-Za-z0-9]{0,99}$/;

/// Callables and HTTP functions of a module, by exported name. Firestore
/// triggers are left out: this server has none (see write_tracking.js).
export function routesOf(module) {
  const routes = new Map();
  for (const [name, value] of Object.entries(module)) {
    const endpoint = typeof value === 'function' ? value.__endpoint : undefined;
    if (!endpoint || !NAME.test(name)) continue;
    if (endpoint.callableTrigger) routes.set(name, { kind: 'callable', handler: value });
    else if (endpoint.httpsTrigger) routes.set(name, { kind: 'request', handler: value });
  }
  return routes;
}

/// Client address seen by the rate limits. Only behind the Fly.io proxy, which
/// writes Fly-Client-IP itself, is the header trusted; elsewhere a client could
/// choose it.
export function clientAddress(request, { trustFlyHeader = false } = {}) {
  const socket = request.socket?.remoteAddress ?? 'unknown';
  if (!trustFlyHeader) return socket;
  const header = request.headers['fly-client-ip'];
  const value = typeof header === 'string' ? header.trim() : '';
  return isIP(value) ? value : socket;
}

function reply(res, status, text, type) {
  if (!res.getHeader('Content-Type')) res.setHeader('Content-Type', type);
  res.statusCode = status;
  res.setHeader('Content-Length', Buffer.byteLength(text));
  res.end(text);
  return res;
}

const replyJson = (res, status, value) => reply(res, status, JSON.stringify(value), 'application/json; charset=utf-8');
const callableError = (status, code, message) => ({ status, body: { error: { message, status: code } } });

/// The Express methods the firebase-functions handlers call.
function decorate(req, res, { body, rawBody, ip }) {
  req.body = body;
  req.rawBody = rawBody;
  req.ip = ip;
  req.header = req.get = (name) => {
    const value = req.headers[String(name).toLowerCase()];
    return Array.isArray(value) ? value.join(', ') : value;
  };
  res.status = (code) => { res.statusCode = code; return res; };
  res.set = (name, value) => { res.setHeader(name, value); return res; };
  res.json = (value) => replyJson(res, res.statusCode, value);
  res.send = (value) => value !== null && typeof value === 'object' && !Buffer.isBuffer(value)
    ? res.json(value)
    : reply(res, res.statusCode, value == null ? '' : String(value), 'text/plain; charset=utf-8');
}

/// Reads the body. Above the limit the rest is discarded so the client still
/// gets the answer; at twice the limit the connection is closed.
function readBody(req, limit) {
  return new Promise((resolve, reject) => {
    const chunks = []; let size = 0;
    req.on('data', (chunk) => {
      size += chunk.length;
      if (size <= limit) { chunks.push(chunk); return; }
      chunks.length = 0;
      if (size > 2 * limit) req.destroy();
    });
    req.on('end', () => (size > limit ? reject(Object.assign(new Error('Body too large'), { tooLarge: true })) : resolve(Buffer.concat(chunks))));
    req.on('error', reject);
    req.on('close', () => { if (!req.complete) reject(new Error('Request aborted')); });
  });
}

function parseBody(req, raw) {
  const type = String(req.headers['content-type'] ?? '').split(';')[0].trim().toLowerCase();
  if (type !== 'application/json') return undefined;
  if (!raw.length) return undefined;
  return JSON.parse(raw.toString('utf8'));
}

/// HTTP server of the routes. `track` runs each handler, so the caller can
/// follow what it writes; `pending` receives every running request, so a
/// shutdown can wait for them.
export function createApiServer({ routes, clientIp = (req) => clientAddress(req), track = (run) => run(),
  maxBodyBytes = MAX_BODY_BYTES, pending = new Set(), log = console } = {}) {
  const server = createServer((req, res) => {
    const work = handle(req, res).catch((error) => {
      log.error?.('Falha ao atender a chamada.', error?.message ?? error);
      if (!res.headersSent) replyJson(res, 500, { error: { message: 'INTERNAL', status: 'INTERNAL' } });
      else res.end();
    }).finally(() => pending.delete(work));
    pending.add(work);
  });
  server.requestTimeout = 60000;
  server.headersTimeout = 20000;
  server.keepAliveTimeout = 65000;

  async function handle(req, res) {
    const path = new URL(req.url ?? '/', 'http://server').pathname;
    const route = routes.get(path.slice(1));
    if (!route || path.lastIndexOf('/') !== 0) {
      req.resume();
      replyJson(res, 404, { error: { message: 'Not Found', status: 'NOT_FOUND' } });
      return;
    }
    let rawBody = Buffer.alloc(0), body;
    if (req.method === 'POST' || req.method === 'PUT' || req.method === 'PATCH') {
      try {
        rawBody = await readBody(req, maxBodyBytes);
        body = parseBody(req, rawBody);
      } catch (error) {
        const failure = error?.tooLarge ? callableError(413, 'INVALID_ARGUMENT', 'Payload Too Large')
          : callableError(400, 'INVALID_ARGUMENT', 'Bad Request');
        if (!res.headersSent) replyJson(res, failure.status, failure.body);
        return;
      }
    } else {
      req.resume();
    }
    decorate(req, res, { body, rawBody, ip: clientIp(req) });
    await track(() => route.handler(req, res));
    if (!res.writableEnded) res.end();
  }

  return server;
}
