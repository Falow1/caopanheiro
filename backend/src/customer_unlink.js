import { HttpsError } from 'firebase-functions/v2/https';
import { onCall } from './callable.js';
import { FieldValue } from 'firebase-admin/firestore';
import { object, identifier } from './runtime.js';
import { teamCommand, metadata } from './team_commands.js';
import { options } from './runtime.js';
import { requirePrincipal } from './staff_privacy.js';
import { jsonCustomer } from './customers.js';
import { tenantAudit } from './tenant_audit.js';
import { hasOpenWork } from './open_work.js';

// Only open records are read, so a long closed history never blocks.
export async function requireNoOpenCustomerWork(tx, db, tenantId, customerId) {
  for (const resource of ['appointments', 'transports', 'transportRequests']) {
    if (await hasOpenWork(tx, db, tenantId, resource, 'customerId', customerId))
      throw new HttpsError('failed-precondition','Existem atendimentos ou transportes abertos deste cliente. Conclua ou cancele antes de desvincular.');
  }
}

export const unlinkCustomerAccount = onCall(options, async request => {
  object(request.data,['tenantId','requestId','customerId','confirmed'],'Desvinculação de cliente');
  if(request.data.confirmed !== true) throw new HttpsError('invalid-argument','Confirme a desvinculação do cliente.');
  const customerId = identifier(request.data.customerId,'Cliente');
  return teamCommand(request,'unlinkCustomerAccount',{customerId,confirmed:true},async({tx,db,tenantId,uid,access})=>{
    requirePrincipal(access.member.data());
    const ref=db.doc(`tenants/${tenantId}/customers/${customerId}`), customer=await tx.get(ref);
    if(!customer.exists)throw new HttpsError('not-found','Cliente não encontrado neste petshop.');
    const tutorUid=customer.get('tutorUid');
    if(!tutorUid)throw new HttpsError('failed-precondition','Este cliente não possui conta vinculada.');
    const member=await tx.get(db.doc(`tenants/${tenantId}/members/${tutorUid}`));
    if(!member.exists || member.get('customerId')!==customerId || !member.get('roles')?.includes('TUTOR'))
      throw new HttpsError('failed-precondition','O vínculo mudou. Atualize os clientes antes de continuar.');
    await requireNoOpenCustomerWork(tx,db,tenantId,customerId);
    const roles=member.get('roles').filter(role=>role!=='TUTOR'), active=member.get('active')===true&&roles.length>0;
    // The mark sends a later entry of the same e-mail by the fixed link to the
    // principal manager, also when the account was deleted and created again.
    tx.update(ref,{tutorUid:null,inviteHash:FieldValue.delete(),tutorUnlinkedAt:FieldValue.serverTimestamp(),...metadata(uid,true)});
    tx.update(member.ref,{roles,active,customerId:FieldValue.delete(),tutorUnlinkedAt:FieldValue.serverTimestamp(),...metadata(uid,true)});
    const link=db.doc(`users/${tutorUid}/tenantLinks/${tenantId}`);
    if(active)tx.set(link,{});else tx.delete(link);
    tx.create(db.collection(`tenants/${tenantId}/workforceEvents`).doc(),{actorUid:uid,targetUid:tutorUid,customerId,action:'TUTOR_UNLINKED',createdAt:FieldValue.serverTimestamp()});
    tenantAudit(tx,db,tenantId,'TUTOR_UNLINKED',uid,access.member.get('name'),{targetUid:tutorUid,customerId});
    return{customer:{...jsonCustomer(customer),tutorUid:null},unlinked:true};
  },['MANAGER'],async({access})=>requirePrincipal(access.member.data()));
});
