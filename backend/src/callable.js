import { onCall as firebaseOnCall, HttpsError } from 'firebase-functions/v2/https';

// Server contract the apps declare in every call. Raise the minimum only
// when older apps can no longer talk to this server: they are told to update
// instead of failing without explanation. Calls that declare nothing (apps
// before 0.17.6, backend tests and scripts) keep being accepted.
export const CLIENT_PROTOCOL_FIELD = 'clientProtocol';
export const MINIMUM_CLIENT_PROTOCOL = 1;
export const APP_OUTDATED_MESSAGE = 'Esta versão do aplicativo não é mais aceita. Atualize o aplicativo para continuar.';

/** Removes the declared contract from the input; refuses older apps. */
export function acceptClient(data, minimum = MINIMUM_CLIENT_PROTOCOL) {
  if (!data || typeof data !== 'object' || Array.isArray(data) || !Object.hasOwn(data, CLIENT_PROTOCOL_FIELD)) return data;
  const { [CLIENT_PROTOCOL_FIELD]: protocol, ...rest } = data;
  if (!Number.isSafeInteger(protocol) || protocol < 1) throw new HttpsError('invalid-argument', 'Versão do aplicativo inválida.');
  if (protocol < minimum) throw new HttpsError('failed-precondition', APP_OUTDATED_MESSAGE, { reason: 'APP_OUTDATED', minimum });
  return rest;
}

/** onCall of the app functions: the contract check runs before the handler. */
export function onCall(options, handler) {
  return firebaseOnCall(options, (request) => handler({ ...request, data: acceptClient(request.data) }));
}
