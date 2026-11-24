import { defineString } from 'firebase-functions/params';
import { backendEnvironment } from './runtime.js';

// Web API key of the real project. The CLI asks for it on the first deploy and
// keeps the answer in backend/.env.<project>, which Git ignores. The emulators
// read "local" from backend/.env.demo-caopanheiro-local.
const webApiKey = defineString('CAOPANHEIRO_WEB_API_KEY', {
  description: 'Chave de API da Web do projeto Firebase (Configurações do projeto > Geral), usada pelo servidor para conferir senhas e pedir e-mails do Auth.',
});

/// Address of an Auth action (accounts:<action>): the emulator of this
/// repository, or the Identity Toolkit of the real project with its web API key.
export function identityToolkitUrl(action, { environment, emulatorHost, apiKey }) {
  const path = `/v1/accounts:${action}?key=`;
  if (environment === 'local') return `http://${emulatorHost}/identitytoolkit.googleapis.com${path}local`;
  if (typeof apiKey !== 'string' || !apiKey.trim() || apiKey === 'local') {
    throw new Error('Chave de API da Web do projeto ausente.');
  }
  return `https://identitytoolkit.googleapis.com${path}${encodeURIComponent(apiKey.trim())}`;
}

/// Address of the Auth password check.
export const passwordCheckUrl = (settings) => identityToolkitUrl('signInWithPassword', settings);

function postToAuth(action, body, headers = {}) {
  const environment = backendEnvironment();
  const url = identityToolkitUrl(action, {
    environment,
    emulatorHost: process.env.FIREBASE_AUTH_EMULATOR_HOST,
    apiKey: environment === 'local' ? undefined : webApiKey.value(),
  });
  return fetch(url, {
    method: 'POST', headers: { 'Content-Type': 'application/json', ...headers },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(10000),
  });
}

/// Checks an e-mail and password with Auth, as an app sign-in would, without
/// keeping any session. Returns the fetch response; a network failure throws,
/// so each caller keeps its own messages and attempt limits. With e-mail
/// enumeration protection on, a wrong e-mail or password answers
/// INVALID_LOGIN_CREDENTIALS.
export function checkPassword(email, password, { returnSecureToken = true } = {}) {
  return postToAuth('signInWithPassword', { email, password, returnSecureToken });
}

/// Asks Auth to send its own e-mail for a new password, in Portuguese, with
/// the template and action page of the project, as the app recovery does.
/// The link never passes through the backend; the emulator keeps it in its
/// oobCodes. Returns the fetch response, as checkPassword.
export function sendPasswordEmail(email) {
  return postToAuth('sendOobCode', { requestType: 'PASSWORD_RESET', email }, { 'X-Firebase-Locale': 'pt-BR' });
}
