import { onCall } from './callable.js';
import { FieldValue } from 'firebase-admin/firestore';
import { actor, accountAvailable, invalid, localBackend, object, options } from './runtime.js';

// Tips over each screen, shown the first time the person opens it. The marks
// live in the account (users/{uid}.screenTips), so they hold on any device:
// seen.{SCREEN} for each screen finished or skipped, and off for "Pular tudo".
export const tipScreens = [
  'TUTOR_HOME', 'TUTOR_BOOKING', 'TUTOR_PETS', 'TUTOR_PROFILE',
  'TUTOR_BOOKING_PETS', 'TUTOR_BOOKING_SCHEDULE', 'TUTOR_BOOKING_CONFIRM', 'TUTOR_APPOINTMENT', 'TUTOR_BREED',
  'TEAM_AGENDA', 'TEAM_CUSTOMERS', 'TEAM_SERVICES', 'TEAM_MORE', 'TEAM_PROFILE',
  'TEAM_APPOINTMENT', 'TEAM_BOOKING', 'TEAM_CUSTOMER', 'TEAM_INVITE_LINK', 'TEAM_PLAN', 'TEAM_RENEWAL', 'TEAM_ACCESS_PAUSED', 'TEAM_EXPORT', 'TEAM_TRANSPORTS', 'TEAM_PET_POLICY', 'TEAM_BREED',
  'PRO_TODAY', 'PRO_AGENDA', 'PRO_PROFILE', 'PRO_APPOINTMENT',
  'DRIVER_TODAY', 'DRIVER_TRANSPORTS', 'DRIVER_HISTORY', 'DRIVER_PROFILE', 'DRIVER_TRANSPORT',
];
const actions = ['SEEN', 'OFF', 'RESET'];

/** Screens already seen (in list order; unknown keys ignored) and whether all are off. */
export function screenTips(profile) {
  const value = profile?.get('screenTips');
  const map = (field) => field && typeof field === 'object' && !Array.isArray(field) ? field : {};
  const seen = map(value?.seen);
  return { seen: tipScreens.filter((screen) => Object.hasOwn(seen, screen)), off: value?.off != null };
}

export const updateScreenTips = onCall(options, async (request) => {
  object(request.data, ['action', 'screen'], 'Dicas');
  const { action, screen } = request.data;
  if (!actions.includes(action)) invalid('Ação de dicas inválida.');
  if (action === 'SEEN' ? !tipScreens.includes(screen) : screen !== undefined) invalid('Tela das dicas inválida.');
  const db = localBackend(), uid = await actor(request), ref = db.doc('users/' + uid);
  const tips = await db.runTransaction(async (tx) => {
    await accountAvailable(tx, db, uid);
    const profile = await tx.get(ref), current = screenTips(profile);
    // Merge keeps the profile and the other marks; a first date never changes.
    if (action === 'SEEN') {
      if (current.seen.includes(screen)) return current;
      tx.set(ref, { screenTips: { seen: { [screen]: FieldValue.serverTimestamp() } } }, { merge: true });
      return { ...current, seen: tipScreens.filter((item) => item === screen || current.seen.includes(item)) };
    }
    if (action === 'OFF') {
      if (!current.off) tx.set(ref, { screenTips: { off: FieldValue.serverTimestamp() } }, { merge: true });
      return { ...current, off: true };
    }
    // "Rever dicas": every screen shows its tips again.
    if (profile.exists && profile.get('screenTips') !== undefined) tx.update(ref, { screenTips: FieldValue.delete() });
    return { seen: [], off: false };
  });
  return { screenTips: tips };
});
