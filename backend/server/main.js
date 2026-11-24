import { pathToFileURL } from 'node:url';
import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { backendEnvironment } from '../src/runtime.js';
import { clientAddress, createApiServer, routesOf } from './api_server.js';
import { runDailyJobs } from './daily_jobs.js';
import { installWriteTracking, withSignals } from './write_tracking.js';

// Entry point of the server of branch dev-banco-fly: the functions of
// backend/src on Fly.io, with Firestore, Auth and Hosting in a Firebase
// project on the Spark plan. The environment guard of runtime.js is the same
// as in Cloud Functions: the emulators of this repository, or a project of
// ALLOWED_PROJECTS without any emulator variable.
//   node server/main.js       serves the calls (PORT, default 8080; 8090 locally)
//   node server/main.js job   runs the daily work once and exits

const LOCAL_PROJECT = 'demo-caopanheiro-local';
const HOUR = 3600000;

function serviceAccount(value) {
  if (typeof value !== 'string' || !value.trim()) throw new Error('Conta de serviço ausente: defina o segredo FIREBASE_SERVICE_ACCOUNT.');
  const text = value.trim().startsWith('{') ? value : Buffer.from(value, 'base64').toString('utf8');
  try { return JSON.parse(text); } catch { throw new Error('Conta de serviço inválida em FIREBASE_SERVICE_ACCOUNT.'); }
}

/// Starts the default Admin app before any call, so callables, token checks
/// and jobs share it. In a real project the credential is the service account
/// of that same project, given as a secret; its value is never logged.
export function startBackendApp(env = process.env) {
  const environment = backendEnvironment(env);
  if (getApps().some((app) => app.name === '[DEFAULT]')) return environment;
  if (environment === 'local') {
    initializeApp({ projectId: LOCAL_PROJECT });
    return environment;
  }
  const account = serviceAccount(env.FIREBASE_SERVICE_ACCOUNT);
  if (account.project_id !== env.GCLOUD_PROJECT) throw new Error('A conta de serviço é de outro projeto.');
  initializeApp({ credential: cert(account), projectId: env.GCLOUD_PROJECT });
  // Child processes and error reports never see the key.
  delete env.FIREBASE_SERVICE_ACCOUNT;
  return environment;
}

async function serve(environment) {
  const db = getFirestore();
  const routes = routesOf(await import('../src/index.js'));
  const onFly = typeof process.env.FLY_APP_NAME === 'string' && process.env.FLY_APP_NAME.length > 0;
  const pending = new Set();
  const track = (work) => withSignals(db, work);
  const server = createApiServer({ routes, pending, track,
    clientIp: (req) => clientAddress(req, { trustFlyHeader: onFly }) });
  const port = Number(process.env.PORT || (environment === 'local' ? 8090 : 8080));
  const host = environment === 'local' ? '127.0.0.1' : '0.0.0.0';
  server.listen(port, host, () => console.log(JSON.stringify({ message: 'Servidor no ar.', port, routes: routes.size, environment })));

  const daily = () => {
    const work = runDailyJobs(db, { track })
      .then((result) => { if (result) console.log(JSON.stringify({ message: 'Rotina diária concluída.', ...result })); })
      .catch((error) => console.error('Falha na rotina diária.', error?.message ?? error))
      .finally(() => pending.delete(work));
    pending.add(work);
  };
  daily();
  const timer = setInterval(daily, HOUR); timer.unref();

  // Fly.io stops an idle machine with SIGINT: finish the calls and the signals
  // in progress before exiting.
  let stopping = false;
  const stop = async () => {
    if (stopping) return; stopping = true;
    clearInterval(timer);
    server.close();
    await Promise.allSettled([...pending]);
    process.exit(0);
  };
  process.on('SIGINT', stop);
  process.on('SIGTERM', stop);
}

async function main(args) {
  if (args.length > 1 || (args.length === 1 && args[0] !== 'job')) throw new Error('Use: node server/main.js [job]');
  const environment = startBackendApp();
  installWriteTracking();
  if (args[0] === 'job') {
    const db = getFirestore();
    const result = await runDailyJobs(db, { force: true, track: (work) => withSignals(db, work) });
    console.log(JSON.stringify({ message: 'Rotina diária concluída.', ...result }));
    // The Firestore client keeps its connections open; the job is over.
    process.exit(0);
  }
  await serve(environment);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main(process.argv.slice(2)).catch((error) => {
    console.error(error?.message ?? error);
    process.exit(1);
  });
}
