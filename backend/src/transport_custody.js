import { HttpsError } from 'firebase-functions/v2/https';
import { digest } from './runtime.js';
const ids=pets=>(pets??[]).map((pet,index)=>pet.id??`legacy-${index}`);
const heldIds=job=>ids(job.pets).filter(id=>!job.collectionChecks||job.collectionChecks.items.some(item=>item.petId===id&&item.confirmed));
export async function prepareTransportLeg(tx,db,tenantId,appointmentId,type,pets,transportId){
 const petIds=ids(pets);
 const page=await tx.get(db.collection(`tenants/${tenantId}/transports`).where('appointmentId','==',appointmentId).limit(101));
 if(page.size>100)throw new HttpsError('failed-precondition','Quantidade de transportes exige revisão administrativa.');
 if(page.docs.some(doc=>doc.id!==transportId&&doc.get('type')===type&&doc.get('status')!=='CANCELLED'&&ids(doc.get('pets')).some(id=>petIds.includes(id))))throw new HttpsError('already-exists','Já existe transporte deste tipo para estes pets. Revise a viagem existente antes de criar ou coletar novamente.');
 const refs=petIds.map(petId=>db.doc(`tenants/${tenantId}/transportPetLocks/${digest(JSON.stringify([appointmentId,type,petId]))}`));
 if(refs.length)await tx.getAll(...refs); // A shared absent/existing lock serializes competing transactions.
 return refs.map((ref,index)=>({ref,value:{appointmentId,type,petId:petIds[index],transportId}}));
}
export function writeTransportLeg(tx,prepared){for(const row of prepared)tx.set(row.ref,row.value);}
export async function prepareCustody(tx,db,tenantId,appointment,job,transportId){
 const customerId=appointment.get('customerId');
 if(!customerId)throw new HttpsError('failed-precondition','Revise o cliente do agendamento antes de coletar.');
 const petIds=heldIds(job);
 const page=await tx.get(db.collection(`tenants/${tenantId}/transports`).where('status','in',['PET_COLLECTED','IN_TRANSIT']).limit(501));
 if(page.size>500)throw new HttpsError('failed-precondition','Quantidade de viagens em andamento exige revisão.');
 const legacy=page.docs.filter(doc=>!doc.get('customerId'));
 const appointments=legacy.length?await tx.getAll(...legacy.map(doc=>db.doc(`tenants/${tenantId}/appointments/${doc.get('appointmentId')}`))):[];
 const legacyCustomers=new Map(legacy.map((doc,index)=>[doc.id,appointments[index].get('customerId')]));
 if(page.docs.some(doc=>doc.id!==transportId&&(doc.get('customerId')??legacyCustomers.get(doc.id))===customerId&&heldIds(doc.data()).some(id=>petIds.includes(id))))throw new HttpsError('failed-precondition','Um destes pets já está sob custódia em outra viagem. Confirme a entrega dessa viagem antes de coletar novamente.');
 const refs=petIds.map(petId=>db.doc(`tenants/${tenantId}/petCustody/${digest(JSON.stringify([customerId,petId]))}`));
 if(refs.length)await tx.getAll(...refs);
 return refs.map((ref,index)=>({ref,value:{customerId,petId:petIds[index],transportId}}));
}
export async function prepareRelease(tx,db,tenantId,appointment,job,transportId){
 const customerId=job.customerId??appointment?.get('customerId');
 if(!customerId)return [];
 const refs=heldIds(job).map(petId=>db.doc(`tenants/${tenantId}/petCustody/${digest(JSON.stringify([customerId,petId]))}`));
 const docs=refs.length?await tx.getAll(...refs):[];
 return docs.filter(doc=>doc.get('transportId')===transportId).map(doc=>doc.ref);
}
export function writeCustody(tx,prepared){for(const row of prepared)tx.set(row.ref,row.value);}
