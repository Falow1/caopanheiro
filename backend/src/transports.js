import { driverEligible } from './workforce_policy.js';
import {requireTransportSchedule} from './transport_schedule.js';
import {prepareTransportLeg,writeTransportLeg,prepareCustody,writeCustody,prepareRelease} from './transport_custody.js';
import { requireReturnReady } from './pet_execution.js';
import {requireAttendantTransportEnabled} from './transport_booking.js';
import { allocateRecordNumbers } from './record_numbers.js';
import { HttpsError } from 'firebase-functions/v2/https';
import { onCall } from './callable.js';
import { FieldPath } from 'firebase-admin/firestore';
import { actor, identifier, invalid, localBackend, object, options, teamAccess, text } from './runtime.js';
import { brazilPhone } from './contact_policy.js';
import { metadata, teamCommand } from './team_commands.js';
import { duration, conflictPreview, requireConflictAcknowledgement, driverReplay, petKey, scheduleInput, scheduleInstant, scheduleKey, transportClock, transportZone } from './transport_operations.js';
import { notify, petNames } from './notices.js';
import { customerTutorUid } from './tutor_access.js';
import { tenantFeature } from './access_policy.js';
import { prepareLocationRelease } from './driver_location.js';
const legLabel=(type)=>type==='PICKUP'?'Coleta':'Retorno';
const tutorStepTitles={GOING_TO_ORIGIN:'Entregador a caminho',PET_COLLECTED:'Pets coletados pelo entregador',IN_TRANSIT:'Pets a caminho do destino',DELIVERED:'Entrega confirmada'};

const address=(input)=>{object(input,['name','street','district','phone'],'Endereço');return{name:text(input.name,'Nome',100,1),street:text(input.street,'Endereço',300,3),district:text(input.district,'Bairro',100,1),phone:brazilPhone(text(input.phone,'Telefone',32,8))};};
const nextStatus={ASSIGNED:'GOING_TO_ORIGIN',GOING_TO_ORIGIN:'PET_COLLECTED',PET_COLLECTED:'IN_TRANSIT',IN_TRANSIT:'DELIVERED'};
export const getCompanyDrivers=onCall(options,async(request)=>{
  const db=localBackend(),uid=await actor(request);
  object(request.data,['tenantId','cursor'],'Consulta');const tenantId=identifier(request.data.tenantId,'Empresa');
  const cursor=request.data.cursor==null?null:identifier(request.data.cursor,'Página');
  return db.runTransaction(async tx=>{
    await teamAccess(tx,db,tenantId,uid);
    let query=db.collection('tenants/'+tenantId+'/members').where('roles','array-contains-any',['DRIVER','MANAGER']).orderBy(FieldPath.documentId()).limit(100);
    if(cursor)query=query.startAfter(cursor);
    const page=await tx.get(query);
    return {drivers:page.docs.filter(doc=>driverEligible(doc.data())).map(doc=>({id:doc.id,recordNumber:doc.get('recordNumber')??null,name:doc.get('name')??'Entregador'})),nextCursor:page.size===100?page.docs.at(-1).id:null};
  });
});
export const createTransport=onCall(options,async(request)=>{
  object(request.data,['tenantId','requestId','transportId','appointmentId','driverUid','type','scheduledAt','localScheduledAt','origin','destination','notes','estimatedDurationMinutes','conflictAcknowledgement'],'Pedido');
  const transportId=identifier(request.data.transportId,'Transporte');const appointmentId=identifier(request.data.appointmentId,'Agendamento');const driverUid=identifier(request.data.driverUid,'Entregador');
  const type=request.data.type;if(!['PICKUP','RETURN'].includes(type))invalid('Tipo de transporte inválido.');
  const schedule=scheduleInput(request.data,true);
  const origin=address(request.data.origin);const destination=address(request.data.destination);const notes=text(request.data.notes??'','Observações',1000);
  const estimatedDurationMinutes=duration(request.data.estimatedDurationMinutes),token=request.data.conflictAcknowledgement??null;
  return teamCommand(request,'createTransport',{transportId,appointmentId,driverUid,type,...scheduleKey(schedule),origin,destination,notes,estimatedDurationMinutes,token},async({db,tx,tenantId,uid,access})=>{
    if(!tenantFeature(access.subscription,'transport'))throw new HttpsError('failed-precondition','Transporte com entregador fica no plano Completo.',{reason:'PLAN_FEATURE'});
    await requireAttendantTransportEnabled(tx,db,tenantId,access);
    const ref=db.doc(`tenants/${tenantId}/transports/${transportId}`);const appointmentRef=db.doc(`tenants/${tenantId}/appointments/${appointmentId}`);
    const [existing,appointment,driver]=await tx.getAll(ref,appointmentRef,db.doc(`tenants/${tenantId}/members/${driverUid}`));
    if(existing.exists)throw new HttpsError('already-exists','Transporte já cadastrado.');
    if(!appointment.exists||['CANCELLED','NO_SHOW'].includes(appointment.get('status')))invalid('Agendamento indisponível para transporte.');
    if(!driver.exists||!driverEligible(driver.data()))throw new HttpsError('permission-denied','Entregador sem vínculo ativo nesta empresa.');
    const zone=transportZone(appointment.data()),scheduledAt=scheduleInstant(schedule,zone);
    if(Date.parse(scheduledAt)<=Date.now())invalid('Escolha um horário futuro.');
    requireTransportSchedule(type,scheduledAt,appointment.data());
    const tutorUid=await customerTutorUid(tx,db,tenantId,appointment.get('customerId'));
    const preview=await conflictPreview(tx,db,tenantId,driverUid,scheduledAt,estimatedDurationMinutes);requireConflictAcknowledgement(preview,token);
    const leg=await prepareTransportLeg(tx,db,tenantId,appointmentId,type,appointment.get('items').map(item=>item.pet),transportId);
    const [recordNumber]=await allocateRecordNumbers(tx,db,tenantId,[{type:'transports',id:transportId}]);
    const transport={recordNumber,appointmentNumber:appointment.get('recordNumber')??null,estimatedDurationMinutes,operationalVersion:2,id:transportId,tenantId,appointmentId,customerId:appointment.get('customerId'),driverUid,type,scheduledAt,...transportClock(scheduledAt,zone),status:'ASSIGNED',origin,destination,notes,pets:appointment.get('items').map((item)=>({id:item.pet.id,recordNumber:item.pet.recordNumber??null,name:item.pet.name,species:item.pet.species??'',breed:item.pet.breed,size:item.pet.size})),events:[{status:'ASSIGNED',createdAt:new Date().toISOString(),actor:uid}],incidents:[],startedAt:null,collectedAt:null,deliveredAt:null};
    writeTransportLeg(tx,leg);
    tx.create(ref,{...transport,...metadata(uid,false)});
    const names=petNames(transport.pets);
    notify(tx,db,tenantId,uid,[
      {role:'DRIVER',targetUid:driverUid,type:'TRANSPORT_ASSIGNED',title:'Novo transporte atribuído',text:`${legLabel(type)} · ${names}`,transportId},
      {role:'TUTOR',targetUid:tutorUid,type:'TRANSPORT_SCHEDULED',title:`${legLabel(type)} agendada pela equipe`.replace('Retorno agendada','Retorno agendado'),text:names,appointmentId}]);
    return{transport};
  });
});
export const transitionTransport=onCall(options,async(request)=>{
  object(request.data,['tenantId','requestId','transportId','expectedStatus','status'],'Pedido');const transportId=identifier(request.data.transportId,'Transporte');const expected=text(request.data.expectedStatus,'Situação anterior',30,1);const status=text(request.data.status,'Situação',30,1);
  if(nextStatus[expected]!==status)invalid('Transição de transporte inválida.');
  return teamCommand(request,'transitionTransport',{transportId,expected,status},async({db,tx,tenantId,uid,access})=>{
    const ref=db.doc(`tenants/${tenantId}/transports/${transportId}`);const previous=await tx.get(ref);
    if(!previous.exists||previous.get('driverUid')!==uid)throw new HttpsError('permission-denied','Transporte não atribuído a você.');
    if(previous.get('status')!==expected)throw new HttpsError('failed-precondition','A situação mudou. Atualize o transporte.');
    if(previous.get('type')==='RETURN'&&status==='GOING_TO_ORIGIN'){const appointment=await tx.get(db.doc(`tenants/${tenantId}/appointments/${previous.get('appointmentId')}`));requireReturnReady(appointment.data()??{},previous.get('pets'));}
    if(status==='PET_COLLECTED'){const checks=previous.get('collectionChecks');if(!checks||!checks.items.some(c=>c.confirmed))throw new HttpsError('failed-precondition','Confira os pets coletados antes de continuar. Se nenhum foi coletado, registre a ocorrencia.');}
    const leg=status==='GOING_TO_ORIGIN'||status==='PET_COLLECTED'?await prepareTransportLeg(tx,db,tenantId,previous.get('appointmentId'),previous.get('type'),previous.get('pets'),transportId):[];
    const custodyAppointment=['PET_COLLECTED','DELIVERED'].includes(status)?await tx.get(db.doc(`tenants/${tenantId}/appointments/${previous.get('appointmentId')}`)):null;
    const tutorUid=await customerTutorUid(tx,db,tenantId,previous.get('customerId'));
    const custody=status==='PET_COLLECTED'?await prepareCustody(tx,db,tenantId,custodyAppointment,previous.data(),transportId):[];
    const release=status==='DELIVERED'?await prepareRelease(tx,db,tenantId,custodyAppointment,previous.data(),transportId):[];
    const location=status==='DELIVERED'?await prepareLocationRelease(tx,db,tenantId,uid,transportId):null;
    const now=new Date().toISOString();
    let deliveryChecks;
    if(status==='DELIVERED'){
      const collection=previous.get('collectionChecks');
      const ids=(previous.get('pets')??[]).map(petKey).filter(id=>!collection||collection.items.some(c=>c.petId===id&&c.confirmed));
      if(!ids.length)throw new HttpsError('failed-precondition','Não há pets coletados para confirmar a entrega.');
      deliveryChecks={items:ids.map(petId=>({petId,confirmed:true,reason:''})),actorUid:uid,actorName:access.member.get('name')??uid,at:now,legacyCollection:!collection,confirmationMode:'ALL_COLLECTED'};
    }
    const patch={status,events:[...previous.get('events'),{status,createdAt:now,actor:access.member.get('name')??uid}],...(status==='GOING_TO_ORIGIN'?{startedAt:now}:{}),...(status==='PET_COLLECTED'?{collectedAt:now}:{}),...(status==='DELIVERED'?{deliveredAt:now,deliveryChecks}:{})};
    writeTransportLeg(tx,leg);writeCustody(tx,custody);for(const ref of release)tx.delete(ref);if(location)tx.delete(location);
    tx.update(ref,{...patch,...metadata(uid,true)});
    notify(tx,db,tenantId,uid,[{role:'TUTOR',targetUid:tutorUid,type:'TRANSPORT_STATUS',title:tutorStepTitles[status],text:`${legLabel(previous.get('type'))} · ${petNames(previous.get('pets'))}`,appointmentId:previous.get('appointmentId')}]);
    return{transport:{...previous.data(),...patch,createdAt:null,updatedAt:null}};
  },['DRIVER'],driverReplay(transportId));
});
export const addTransportIncident=onCall(options,async(request)=>{
  object(request.data,['tenantId','requestId','transportId','type','description'],'Pedido');const transportId=identifier(request.data.transportId,'Transporte');const type=text(request.data.type,'Tipo',80,1);const description=text(request.data.description,'Descrição',2000,1);
  return teamCommand(request,'addTransportIncident',{transportId,type,description},async({db,tx,tenantId,uid,access})=>{
    const ref=db.doc(`tenants/${tenantId}/transports/${transportId}`);const previous=await tx.get(ref);
    if(!previous.exists||previous.get('driverUid')!==uid)throw new HttpsError('permission-denied','Transporte não atribuído a você.');
    if(['CANCELLED','DELIVERED'].includes(previous.get('status')))throw new HttpsError('failed-precondition','Transporte encerrado.');
    const incidents=previous.get('incidents')??[];if(incidents.length>=100)invalid('Limite de ocorrências atingido.');
    const tutorUid=await customerTutorUid(tx,db,tenantId,previous.get('customerId'));
    const updated=[...incidents,{id:request.data.requestId,status:'OPEN',type,description,createdAt:new Date().toISOString(),driverName:access.member.get('name')??uid,driverUid:uid}];tx.update(ref,{incidents:updated,...metadata(uid,true)});
    const names=petNames(previous.get('pets'));
    // The tutor learns that something happened; the description stays with the team.
    notify(tx,db,tenantId,uid,[
      {role:'TEAM',type:'TRANSPORT_INCIDENT',title:'Ocorrência em transporte',text:`${type} · ${access.member.get('name')??'Entregador'} · ${names}`,transportId,appointmentId:previous.get('appointmentId')},
      {role:'TUTOR',targetUid:tutorUid,type:'TRANSPORT_INCIDENT',title:'Ocorrência no transporte dos seus pets',text:'A equipe do petshop foi avisada e está acompanhando.',appointmentId:previous.get('appointmentId')}]);
    return{transport:{...previous.data(),incidents:updated,createdAt:null,updatedAt:null}};
  },['DRIVER'],driverReplay(transportId));
});
