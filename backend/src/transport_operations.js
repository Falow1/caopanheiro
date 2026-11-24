import { driverEligible } from './workforce_policy.js';
import {prepareTransportLeg,writeTransportLeg} from './transport_custody.js';
import { returnReadiness } from './pet_execution.js';
import { HttpsError } from 'firebase-functions/v2/https';
import { onCall } from './callable.js';
import { FieldPath } from 'firebase-admin/firestore';
import { actor, identifier, invalid, localBackend, object, options, teamAccess, text, digest } from './runtime.js';
import { metadata, teamCommand } from './team_commands.js';
import { notify, petNames } from './notices.js';
import { defaultTimeZone, localInstant, localLabel } from './calendar.js';

import { openTransportStatuses } from './open_work.js';
export { openTransportStatuses };
export const transportJson = (doc) => ({id:doc.id,...doc.data(),createdAt:null,updatedAt:null});
/** Zone of a transport: the one its appointment was booked in, the company's. */
export const transportZone = (appointment) => appointment?.timeZone ?? defaultTimeZone;
/** Company wall clock kept beside the instant, as appointments keep localStartsAt. */
export const transportClock = (scheduledAt, zone) => ({localScheduledAt:localLabel(Date.parse(scheduledAt),zone),timeZone:zone});
/**
 * Transport time chosen by the team: the company wall clock (localScheduledAt,
 * converted with the company zone) or, from older clients, a UTC instant.
 */
export function scheduleInput(data, strictUtc) {
  if((data.localScheduledAt==null)===(data.scheduledAt==null))invalid('Informe o horário do transporte.');
  if(data.localScheduledAt!=null)return{local:text(data.localScheduledAt,'Horário',19,16),utc:null};
  const utc=text(data.scheduledAt,'Horário',40,20);
  if(strictUtc&&!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?Z$/.test(utc)||!Number.isFinite(Date.parse(utc)))invalid(strictUtc?'Horário UTC inválido.':'Horário inválido.');
  return{local:null,utc};
}
export function scheduleInstant(input, zone) {
  if(input.local==null)return input.utc;
  const at=localInstant(input.local,zone);if(at==null)invalid('Horário inválido no fuso da empresa.');
  return new Date(at).toISOString();
}
export const scheduleKey = (input) => input.local==null?{scheduledAt:input.utc}:{localScheduledAt:input.local};
export const petKey = (pet,index) => pet.id ?? `legacy-${index}`;
export const incidentKey = (incident,index) => incident.id ?? `legacy-${index}`;
export function duration(value) {
  if(value == null) return null;
  if(!Number.isSafeInteger(value)||value<1||value>720) invalid('Informe duracao estimada entre 1 e 720 minutos.');
  return value;
}
export function conflictsFor(rows,driverUid,scheduledAt,minutes,excludeId=null) {
  const start=Date.parse(scheduledAt);
  return rows.filter(row=>row.id!==excludeId && row.driverUid===driverUid && openTransportStatuses.includes(row.status))
    .filter(row=>{const other=Date.parse(row.scheduledAt);return minutes && row.estimatedDurationMinutes
      ? start<other+row.estimatedDurationMinutes*60000 && other<start+minutes*60000 : start===other;})
    .map(row=>({id:row.id,scheduledAt:row.scheduledAt,localScheduledAt:row.localScheduledAt??null,status:row.status,estimatedDurationMinutes:row.estimatedDurationMinutes??null}))
    .sort((a,b)=>a.id.localeCompare(b.id));
}
export async function conflictPreview(tx,db,tenantId,driverUid,scheduledAt,minutes,excludeId=null) {
  const page=await tx.get(db.collection(`tenants/${tenantId}/transports`).where('driverUid','==',driverUid).where('status','in',openTransportStatuses).limit(501));
  if(page.size>500) throw new HttpsError('resource-exhausted','Agenda do entregador requer paginacao ampliada.');
  const rows=page.docs.map(transportJson),conflicts=conflictsFor(rows,driverUid,scheduledAt,minutes,excludeId);
  return {conflicts,incomplete:!minutes||rows.some(row=>!row.estimatedDurationMinutes),
    acknowledgement:digest(JSON.stringify([tenantId,driverUid,scheduledAt,minutes,excludeId,conflicts]))};
}
export function requireConflictAcknowledgement(preview,token) {
  if(preview.conflicts.length && token!==preview.acknowledgement) throw new HttpsError('failed-precondition','Ha conflitos de horario. Atualize e confirme os avisos antes de continuar.');
}
export const driverReplay = (id) => async ({tx,db,tenantId,uid}) => {
  const doc=await tx.get(db.doc(`tenants/${tenantId}/transports/${id}`));
  if(!doc.exists||doc.get('driverUid')!==uid) throw new HttpsError('permission-denied','Transporte nao atribuido a voce.');
};
export const getTransportConflicts=onCall(options,async request=>{
  object(request.data,['tenantId','driverUid','scheduledAt','localScheduledAt','appointmentId','estimatedDurationMinutes','excludeId'],'Consulta');
  const db=localBackend(),uid=await actor(request),tenantId=identifier(request.data.tenantId,'Empresa');
  const driverUid=identifier(request.data.driverUid,'Entregador'),schedule=scheduleInput(request.data,false),minutes=duration(request.data.estimatedDurationMinutes);
  // A company wall clock is read in the zone of the appointment, as on creation.
  const appointmentId=schedule.local==null?null:identifier(request.data.appointmentId,'Agendamento');
  const excludeId=request.data.excludeId==null?null:identifier(request.data.excludeId,'Transporte');
  return db.runTransaction(async tx=>{await teamAccess(tx,db,tenantId,uid);
    const appointment=appointmentId?await tx.get(db.doc(`tenants/${tenantId}/appointments/${appointmentId}`)):null;
    if(appointment&&!appointment.exists)invalid('Agendamento indisponível.');
    const scheduledAt=scheduleInstant(schedule,transportZone(appointment?.data()));
    return{...await conflictPreview(tx,db,tenantId,driverUid,scheduledAt,minutes,excludeId),scheduledAt};});
});
export const getCompanyTransports=onCall(options,async request=>{
  object(request.data,['tenantId','cursor','appointmentId'],'Consulta');
  const db=localBackend(),uid=await actor(request),tenantId=identifier(request.data.tenantId,'Empresa');
  const appointmentId=request.data.appointmentId==null?null:identifier(request.data.appointmentId,'Agendamento');
  const cursor=request.data.cursor==null?null:identifier(request.data.cursor,'Pagina');
  return db.runTransaction(async tx=>{await teamAccess(tx,db,tenantId,uid);
    let query=db.collection(`tenants/${tenantId}/transports`);if(appointmentId)query=query.where('appointmentId','==',appointmentId);
    query=query.orderBy(FieldPath.documentId()).limit(50);if(cursor)query=query.startAfter(cursor);
    const page=await tx.get(query);const rows=page.docs.map(transportJson);const refs=[...new Set(rows.map(job=>job.appointmentId))].map(id=>db.doc(`tenants/${tenantId}/appointments/${id}`));const appointments=refs.length?await tx.getAll(...refs):[];const byId=new Map(appointments.map(doc=>[doc.id,doc.data()??{}]));return{items:rows.map(job=>({...job,...(job.localScheduledAt||!job.scheduledAt?{}:transportClock(job.scheduledAt,transportZone(byId.get(job.appointmentId)))),pets:returnReadiness(byId.get(job.appointmentId)??{},job.pets??[])})),nextCursor:page.size===50?page.docs.at(-1).id:null};});
});
export const reassignTransport=onCall(options,async request=>{
  object(request.data,['tenantId','requestId','transportId','driverUid','expectedDriverUid','expectedStatus','reason','custodyConfirmed','conflictAcknowledgement'],'Pedido');
  const transportId=identifier(request.data.transportId,'Transporte'),driverUid=identifier(request.data.driverUid,'Entregador');
  const expectedDriverUid=identifier(request.data.expectedDriverUid,'Responsavel atual'),expectedStatus=text(request.data.expectedStatus,'Situacao',40,1),reason=text(request.data.reason,'Motivo',1000,3);
  const custodyConfirmed=request.data.custodyConfirmed===true,token=request.data.conflictAcknowledgement??null;
  return teamCommand(request,'reassignTransport',{transportId,driverUid,expectedDriverUid,expectedStatus,reason,custodyConfirmed,token},async({db,tx,tenantId,uid,access})=>{
    const ref=db.doc(`tenants/${tenantId}/transports/${transportId}`);const previous=await tx.get(ref);
    if(!previous.exists||!openTransportStatuses.includes(previous.get('status')))throw new HttpsError('failed-precondition','Transporte encerrado ou indisponivel.');
    if(previous.get('driverUid')!==expectedDriverUid||previous.get('status')!==expectedStatus)throw new HttpsError('failed-precondition','O transporte mudou. Atualize antes de trocar o responsavel.');
    if(driverUid===expectedDriverUid)invalid('Escolha outro entregador.');
    const inCustody=['PET_COLLECTED','IN_TRANSIT'].includes(expectedStatus);
    if(inCustody&&(!access.member.get('roles').includes('MANAGER')||!custodyConfirmed))throw new HttpsError('failed-precondition','A transferencia de pets coletados exige gestor e confirmacao da transferencia fisica.');
    const driver=await tx.get(db.doc(`tenants/${tenantId}/members/${driverUid}`));
    if(!driver.exists || !driverEligible(driver.data()))throw new HttpsError('permission-denied','Novo entregador sem vinculo ativo.');
    const preview=await conflictPreview(tx,db,tenantId,driverUid,previous.get('scheduledAt'),previous.get('estimatedDurationMinutes')??null,transportId);
    requireConflictAcknowledgement(preview,token);
    const assignmentHistory=previous.get('assignmentHistory')??[];if(assignmentHistory.length>=100)invalid('Limite de transferencias atingido.');
    const change={fromUid:expectedDriverUid,toUid:driverUid,reason,custodyConfirmed:inCustody,actorUid:uid,actorName:access.member.get('name')??uid,at:new Date().toISOString()};
    tx.update(ref,{driverUid,assignmentHistory:[...assignmentHistory,change],...metadata(uid,true)});
    const names=petNames(previous.get('pets'));
    notify(tx,db,tenantId,uid,[
      {role:'DRIVER',targetUid:driverUid,type:'TRANSPORT_ASSIGNED',title:'Novo transporte atribuído',text:names,transportId},
      {role:'DRIVER',targetUid:expectedDriverUid,type:'TRANSPORT_REASSIGNED',title:'Transporte passou para outro entregador',text:names,transportId}]);
    return{transport:{...transportJson(previous),driverUid,assignmentHistory:[...assignmentHistory,change]},conflicts:preview.conflicts};
  });
});
export const manageTransportIncident=onCall(options,async request=>{
  object(request.data,['tenantId','requestId','transportId','incidentId','status','message'],'Pedido');
  const transportId=identifier(request.data.transportId,'Transporte'),incidentId=identifier(request.data.incidentId,'Ocorrencia');
  const status=request.data.status;if(!['ACKNOWLEDGED','RESOLVED'].includes(status))invalid('Situacao de ocorrencia invalida.');
  const message=text(request.data.message,'Resposta ou solucao',2000,3);
  return teamCommand(request,'manageTransportIncident',{transportId,incidentId,status,message},async({db,tx,tenantId,uid,access})=>{
    const ref=db.doc(`tenants/${tenantId}/transports/${transportId}`),previous=await tx.get(ref);if(!previous.exists)throw new HttpsError('not-found','Transporte indisponivel.');
    const incidents=previous.get('incidents')??[],index=incidents.findIndex((v,i)=>incidentKey(v,i)===incidentId);
    if(index<0)throw new HttpsError('not-found','Ocorrencia indisponivel.');
    const old=incidents[index];if(old.status==='RESOLVED')throw new HttpsError('failed-precondition','Ocorrencia ja resolvida.');
    const history=old.responses??[];if(history.length>=30)invalid('Limite de respostas atingido.');
    const response={status,message,actorUid:uid,actorName:access.member.get('name')??uid,at:new Date().toISOString()};
    incidents[index]={...old,id:incidentId,status,...(status==='RESOLVED'?{resolution:message}:{response:message}),responses:[...history,response],updatedAt:response.at};
    tx.update(ref,{incidents,...metadata(uid,true)});
    notify(tx,db,tenantId,uid,[{role:'DRIVER',targetUid:old.driverUid??previous.get('driverUid'),type:'TRANSPORT_INCIDENT',title:status==='RESOLVED'?'Ocorrência resolvida pela equipe':'Equipe respondeu à ocorrência',text:petNames(previous.get('pets')),transportId}]);
    return{transport:{...transportJson(previous),incidents}};
  });
});
export const checkTransportPets=onCall(options,async request=>{
  object(request.data,['tenantId','requestId','transportId','phase','checks'],'Pedido');
  const transportId=identifier(request.data.transportId,'Transporte'),phase=request.data.phase;
  if(!['COLLECTION','DELIVERY'].includes(phase)||!Array.isArray(request.data.checks)||request.data.checks.length>50)invalid('Conferencia invalida.');
  const checks=request.data.checks.map(value=>{object(value,['petId','confirmed','reason'],'Pet');if(typeof value.confirmed!=='boolean')invalid('Confirme a situacao do pet.');return{petId:identifier(value.petId,'Pet'),confirmed:value.confirmed,reason:text(value.reason??'','Motivo',1000,value.confirmed?0:3)};});
  if(new Set(checks.map(c=>c.petId)).size!==checks.length)invalid('Pet repetido na conferencia.');
  return teamCommand(request,'checkTransportPets',{transportId,phase,checks},async({db,tx,tenantId,uid,access})=>{
    const ref=db.doc(`tenants/${tenantId}/transports/${transportId}`),previous=await tx.get(ref);
    if(!previous.exists||previous.get('driverUid')!==uid)throw new HttpsError('permission-denied','Transporte nao atribuido a voce.');
    const expected=phase==='COLLECTION'?'GOING_TO_ORIGIN':'IN_TRANSIT';if(previous.get('status')!==expected)throw new HttpsError('failed-precondition','Atualize a etapa antes de conferir.');
    const pets=previous.get('pets')??[],collection=previous.get('collectionChecks');
    const ids=pets.map(petKey).filter(id=>phase==='COLLECTION'||!collection||collection.items.some(c=>c.petId===id&&c.confirmed));
    if(!ids.length||checks.length!==ids.length||checks.some(c=>!ids.includes(c.petId)))invalid('Confira exatamente os pets desta etapa.');
    const leg=phase==='COLLECTION'?await prepareTransportLeg(tx,db,tenantId,previous.get('appointmentId'),previous.get('type'),pets,transportId):[];
    const now=new Date().toISOString(),record={items:checks,actorUid:uid,actorName:access.member.get('name')??uid,at:now,legacyCollection:phase==='DELIVERY'&&!collection};
    const incidents=previous.get('incidents')??[];
    const exceptions=checks.filter(c=>!c.confirmed).map(c=>({id:digest(JSON.stringify([request.data.requestId,c.petId,phase])),type:'Excecao na conferencia',description:`${phase==='COLLECTION'?'Coleta':'Entrega'}: ${pets.find((p,i)=>petKey(p,i)===c.petId)?.name??c.petId} - ${c.reason}`,petId:c.petId,status:'OPEN',createdAt:now,driverName:access.member.get('name')??uid,driverUid:uid}));
    if(incidents.length+exceptions.length>100)invalid('Limite de ocorrencias atingido.');
    const patch={[phase==='COLLECTION'?'collectionChecks':'deliveryChecks']:record,incidents:[...incidents,...exceptions]};
    writeTransportLeg(tx,leg);tx.update(ref,{...patch,...metadata(uid,true)});return{transport:{...transportJson(previous),...patch}};
  },['DRIVER'],driverReplay(transportId));
});
