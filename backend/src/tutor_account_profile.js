import { onCall } from './callable.js';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue } from 'firebase-admin/firestore';
import { actor, accountAvailable, localBackend, object, options, text } from './runtime.js';
import { brazilPhone } from './contact_policy.js';

// A contact number is not an Auth-verified phone number and grants no role.
export const saveTutorAccountProfile = onCall(options, async request => {
  object(request.data, ['name', 'phone'], 'Perfil da própria conta');
  const name = text(request.data.name, 'Nome', 100, 2);
  const phone = brazilPhone(text(request.data.phone, 'Telefone', 32, 8));
  const db = localBackend(), uid = await actor(request);
  const account = await getAuth().getUser(uid);
  await db.runTransaction(async tx => {
    await accountAvailable(tx, db, uid);
    tx.set(db.doc('users/' + uid), {name, phone, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
  });
  return {profile: {id: uid, name, phone, email: account.email ?? ''}};
});
