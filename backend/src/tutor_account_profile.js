import { onCall } from './callable.js';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue } from 'firebase-admin/firestore';
import { actor, accountAvailable, invalid, localBackend, object, options, text } from './runtime.js';
import { point } from './transport_booking.js';
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

// Address of the tutor for the transport: street, district and the point
// marked on the map, kept in the account like the name and the phone, so it
// comes back filled in every petshop. null removes it. Only the tutor reads it.
export function tutorAddressInput(value) {
  if (value === null) return null;
  object(value, ['street', 'district', 'point'], 'Endereço');
  return { street: text(value.street, 'Endereço e número', 300, 3), district: text(value.district, 'Bairro/cidade', 150, 1), point: point(value.point) };
}
export const saveTutorAddress = onCall(options, async request => {
  object(request.data, ['address'], 'Endereço da própria conta');
  if (!Object.hasOwn(request.data, 'address')) invalid('Informe o endereço.');
  const address = tutorAddressInput(request.data.address);
  const db = localBackend(), uid = await actor(request);
  await db.runTransaction(async tx => {
    await accountAvailable(tx, db, uid);
    tx.set(db.doc('users/' + uid), { tutorAddress: address ? { ...address, updatedAt: new Date().toISOString() } : FieldValue.delete(), updatedAt: FieldValue.serverTimestamp() }, { merge: true });
  });
  return { address };
});
