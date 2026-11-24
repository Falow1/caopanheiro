import { HttpsError } from 'firebase-functions/v2/https';
import { metadata } from './team_commands.js';
export async function prepareProfessionalAppointments(tx,db,tenantId,professionalId){
 const page=await tx.get(db.collection(`tenants/${tenantId}/appointments`).where('professionalId','==',professionalId).where('status','in',['REQUESTED','CONFIRMED','PET_RECEIVED','IN_PROGRESS']).limit(401));
 if(page.size>400)throw new HttpsError('failed-precondition','Quantidade de atendimentos abertos exige revisão antes de vincular a conta.');
 return page.docs.filter(doc=>doc.get('professionalUid')==null);
}
export function writeProfessionalAppointments(tx,rows,targetUid,actorUid){
 for(const doc of rows)tx.update(doc.ref,{professionalUid:targetUid,...metadata(actorUid,true)});
}
