import { HttpsError } from 'firebase-functions/v2/https';
import { metadata } from './team_commands.js';
const openStatuses=['REQUESTED','CONFIRMED','PET_RECEIVED','IN_PROGRESS'];
// Open appointments of a professional record still without an account: the
// professional of the appointment (older ones) or of at least one pet.
export async function prepareProfessionalAppointments(tx,db,tenantId,professionalId){
 const collection=db.collection(`tenants/${tenantId}/appointments`);
 const pages=await Promise.all([collection.where('professionalId','==',professionalId),collection.where('professionalIds','array-contains',professionalId)].map(query=>tx.get(query.where('status','in',openStatuses).limit(401))));
 if(pages.some(page=>page.size>400))throw new HttpsError('failed-precondition','Quantidade de atendimentos abertos exige revisão antes de vincular a conta.');
 const docs=new Map(pages.flatMap(page=>page.docs).map(doc=>[doc.id,doc]));
 const unassigned=(doc)=>doc.get('professionalId')===professionalId&&doc.get('professionalUid')==null||(doc.get('items')??[]).some(item=>item.professionalId===professionalId&&item.professionalUid==null);
 return [...docs.values()].filter(unassigned).map(doc=>({doc,professionalId}));
}
export function writeProfessionalAppointments(tx,rows,targetUid,actorUid){
 for(const {doc,professionalId} of rows){
  const items=(doc.get('items')??[]).map(item=>item.professionalId===professionalId&&item.professionalUid==null?{...item,professionalUid:targetUid}:item);
  const lead=doc.get('professionalId')===professionalId&&doc.get('professionalUid')==null;
  const uids=[...new Set([...(doc.get('professionalUids')??[]),...items.filter(item=>item.professionalId===professionalId).map(()=>targetUid),...(lead?[targetUid]:[])])];
  tx.update(doc.ref,{...(lead?{professionalUid:targetUid}:{}),...(doc.get('professionalIds')?{items,professionalUids:uids}:{}),...metadata(actorUid,true)});
 }
}
