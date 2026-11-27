import { publicProfessional } from './staff_privacy.js';
import {prepareProfessionalAppointments,writeProfessionalAppointments} from './professional_binding.js';
import { staffSeatOccupied } from './manager_activation.js';
import { requireEditableWorkforceMember, requireNoOpenAssignments } from './workforce_access.js';
import { normalizeServiceQuote,serviceQuote,quoteMatches } from './service_quote.js';
import { reservationState,samePet } from './pet_reservations.js';
import { executionItems, changePetExecution } from './pet_execution.js';
import { authorizeBlock, canEditBlock, blockStartsAt } from './block_policy.js';
import {prepareBookingTransport,writeBookingTransport,prepareTransportCancellation,writeTransportCancellation} from './transport_booking.js';
import { allocateRecordNumbers, petNumberId } from './record_numbers.js';
import { HttpsError } from 'firebase-functions/v2/https';
import { onCall } from './callable.js';
import { FieldPath, FieldValue, Timestamp } from 'firebase-admin/firestore';
import { getAuth } from 'firebase-admin/auth';
import { actor, email, identifier, invalid, localBackend, object, options, teamAccess, text } from './runtime.js';
import { metadata, teamCommand } from './team_commands.js';
import { civil, dayValue, defaultTimeZone, jsonDays, minute, overlaps, stateTimeZone, timeLabel, timeZone, weekDays, within, zonedInstant } from './calendar.js';
import { notify, noticeDate, petNames } from './notices.js';
import { customerTutorUid } from './tutor_access.js';
import { BOOKINGS_PAUSED, TEAM_BOOKINGS_PAUSED, TUTOR_APP_CLOSED } from './access_policy.js';
import { evaluatePet, normalizedPet, petBlocksRef, petPolicyRef, petServiceMessage, storedPetPolicy } from './pet_policy.js';

const schedulingRoles = ['MANAGER','ATTENDANT','TUTOR'];
// After the deadline of an expired plan (E2), nobody books or moves an
// appointment; the tutor is never told that the reason is payment.
function refusePausedBooking(access) {
  if (access.billing?.phase !== BOOKINGS_PAUSED) return;
  const team = access.member.get('roles').some((role) => ['MANAGER','ATTENDANT'].includes(role));
  throw new HttpsError('failed-precondition', team ? TEAM_BOOKINGS_PAUSED : TUTOR_APP_CLOSED, { reason: 'BOOKINGS_PAUSED' });
}
// A pet the petshop does not serve, or marked "Não atender este pet", is not
// booked, rescheduled or added to an appointment; appointments already booked
// stay valid. The tutor reads the neutral text, never the reason of a block.
function refuseUnservedPets(booking, access, petIds) {
  const refused = booking.unserved.find(({ pet }) => petIds.includes(pet.id));
  if (!refused) return;
  const team = access.member.get('roles').some((role) => ['MANAGER','ATTENDANT'].includes(role));
  throw new HttpsError('failed-precondition', petServiceMessage(refused.reason, refused.pet, { tutor: !team, petshop: team ? undefined : access.tenant?.get('tradeName') ?? 'O petshop' }),
    { reason: 'PET_NOT_SERVED', petId: refused.pet.id, service: refused.reason });
}
const liveStatuses = ['REQUESTED','CONFIRMED','PET_RECEIVED','IN_PROGRESS'];
const policyRef = (db,tenant) => db.doc(`tenants/${tenant}/settings/scheduling`);
const dayRef = (db,tenant,day) => db.doc(`tenants/${tenant}/scheduleDays/${day}`);
export const jsonAppointment = (doc) => ({ id: doc.id, ...doc.data(), items:executionItems(doc.data()), startsAt: doc.get('startsAt').toDate().toISOString(), endsAt: doc.get('endsAt').toDate().toISOString(), createdAt: null, updatedAt: null });
// Tutor view: the team's internal notes and who on the team wrote or changed the
// record stay on the server; professional observations travel without their author.
// professionalUid stays: the tutor app receives the server-chosen professional.
const events = (list) => list.map(({ status, at }) => ({ status, at }));
export function tutorView(value) {
  const { notes, createdBy, updatedBy, ...rest } = value;
  return { ...rest, ...(Array.isArray(rest.history) ? { history: events(rest.history) } : {}),
    ...(Array.isArray(rest.observations) ? { observations: rest.observations.map(({ petId, text, createdAt }) => ({ petId, text, createdAt })) } : {}),
    items: (rest.items ?? []).map((item) => {
      if (!item.execution) return item;
      const { startedBy, completedBy, ...execution } = item.execution;
      return { ...item, execution: { ...execution, ...(Array.isArray(execution.history) ? { history: events(execution.history) } : {}) } };
    }) };
}

export function selection(value) {
  if (!Array.isArray(value) || value.length < 1 || value.length > 10) invalid('Escolha de um a dez pets.');
  const seen = new Set(); let count = 0;
  return value.map((item) => {
    object(item, ['petId','serviceIds'], 'Itens');
    const petId = identifier(item.petId, 'Pet');
    if (seen.has(petId)) invalid('Pet repetido.'); seen.add(petId);
    if (!Array.isArray(item.serviceIds) || !item.serviceIds.length || item.serviceIds.length > 20) invalid('Escolha os serviços de cada pet.');
    const serviceIds = item.serviceIds.map((id) => identifier(id,'Serviço'));
    count += serviceIds.length;
    if (new Set(serviceIds).size !== serviceIds.length || count > 50) invalid('Serviços repetidos ou quantidade excedida.');
    return { petId, serviceIds };
  });
}

export async function bookingData(tx, db, tenantId, uid, access, customerId, items) {
  const [customer, policy, petPolicy, petBlocks] = await tx.getAll(db.doc(`tenants/${tenantId}/customers/${customerId}`), policyRef(db,tenantId), petPolicyRef(db,tenantId), petBlocksRef(db,tenantId,customerId));
  if (!customer.exists) throw new HttpsError('not-found','Cliente não encontrado.');
  const team = access.member.get('roles').some((role) => ['MANAGER','ATTENDANT'].includes(role));
  if (!team && (customer.get('tutorUid') !== uid || access.member.get('customerId') !== customerId)) throw new HttpsError('permission-denied','Este cadastro não pertence à sua conta.');
  if (!policy.exists) throw new HttpsError('failed-precondition','O gerente precisa salvar os horários da empresa antes de receber agendamentos.');
  const serviceIds = [...new Set(items.flatMap((item) => item.serviceIds))];
  const services = await tx.getAll(...serviceIds.map((id) => db.doc(`tenants/${tenantId}/services/${id}`)));
  const serviceMap = new Map(services.map((doc) => [doc.id,doc]));
  let durationMinutes = 0; let priceCents = 0;
  const servicePolicy = storedPetPolicy(petPolicy), blocks = petBlocks.get('pets') ?? {}, unserved = [];
  const confirmedItems = items.map((item) => {
    const stored = customer.get('pets')?.[item.petId];
    if (!stored) invalid('O pet não pertence ao cliente selecionado.');
    // The appointment keeps the pet with the breed and size of the list.
    const { breedPending, legacyBreed, ...pet } = normalizedPet(stored);
    const result = evaluatePet(servicePolicy, pet, { blocked: !!blocks[pet.id] });
    if (!result.served) unserved.push({ pet, reason: result.reason });
    const confirmed = item.serviceIds.map((id) => {
      const doc = serviceMap.get(id);
      if (!doc?.exists || doc.get('active') !== true) invalid('Serviço indisponível.');
      const duration = doc.get('durationMinutes'); const price = doc.get('priceCents');
      if (!Number.isSafeInteger(duration) || duration <= 0 || !Number.isSafeInteger(price) || price < 0) invalid('Serviço com dados inválidos.');
      durationMinutes += duration; priceCents += price;
      return { id, recordNumber: doc.get('recordNumber') ?? null, name: doc.get('name'), description: doc.get('description') ?? '', durationMinutes: duration, priceCents: price, active:true };
    });
    return { pet, services: confirmed };
  });
  if (durationMinutes > 1440 || !Number.isSafeInteger(priceCents)) invalid('Duração ou valor do atendimento inválido.');
  if(!Number.isSafeInteger(policy.get('slotMinutes'))||policy.get('slotMinutes')<5||policy.get('slotMinutes')>120)throw new HttpsError('failed-precondition','Horários da empresa precisam ser revisados pelo gerente.');
  const professionalDocs = await tx.get(db.collection(`tenants/${tenantId}/professionals`).where('active','==',true).limit(101));
  if (professionalDocs.size > 100) throw new HttpsError('failed-precondition','Quantidade de profissionais requer paginação administrativa.');
  const linked=professionalDocs.docs.filter(doc=>doc.get('authUid'));
  const members=linked.length?await tx.getAll(...linked.map(doc=>db.doc(`tenants/${tenantId}/members/${doc.get('authUid')}`))):[];
  const eligible=new Set(linked.filter((doc,index)=>members[index].get('active')===true&&members[index].get('roles')?.some(role=>['PROFESSIONAL','MANAGER'].includes(role))&&(!members[index].get('professionalId')||members[index].get('professionalId')===doc.id)).map(doc=>doc.id));
  const unlinked=professionalDocs.docs.filter(doc=>!doc.get('authUid'));
  const unlinkedAllowed=new Set();
  for(const doc of unlinked){
    const contact=doc.get('email');
    const matches=contact?await tx.get(db.collection(`tenants/${tenantId}/members`).where('email','==',contact.toLowerCase()).limit(2)):null;
    if(!matches||matches.empty||matches.size===1&&matches.docs[0].get('active')===true&&matches.docs[0].get('roles')?.some(role=>['PROFESSIONAL','MANAGER'].includes(role))&&(!matches.docs[0].get('professionalId')||matches.docs[0].get('professionalId')===doc.id))unlinkedAllowed.add(doc.id);
  }
  return { customer: { id:customer.id, recordNumber:customer.get('recordNumber') ?? null, name:customer.get('name'), phone:customer.get('phone'), email:customer.get('email'), pets:confirmedItems.map((item) => item.pet) },
    tutorUid:customer.get('tutorUid') ?? null, items:confirmedItems, unserved, durationMinutes, priceCents, policy:policy.data(), professionals:professionalDocs.docs.filter(doc=>eligible.has(doc.id)||unlinkedAllowed.has(doc.id)) };
}

export function professionalAvailable(booking, professional, day, state, start, end, excludeId) {
  const weeklyDay = civil(zonedInstant(day,720,booking.policy.timeZone),booking.policy.timeZone).weekDay;
  if (!within(booking.policy.days[weeklyDay],start,end)) return false;
  if (professional.get('availability') && !within(professional.get('availability')[weeklyDay],start,end)) return false;
  const interval = { start,end };
  if (Object.values(state.blocks ?? {}).some((block) => overlaps(interval,block))) return false;
  return !Object.entries(state.reservations ?? {}).some(([id, value]) => id !== excludeId && (value.professionalId === professional.id || samePet(booking,value)) && overlaps(interval,value));
}

export const getAvailableSlots = onCall(options, async (request) => {
  const db = localBackend(); const uid = await actor(request);
  object(request.data,['tenantId','customerId','day','items','professionalId','appointmentId'],'Consulta');
  const tenantId = identifier(request.data.tenantId,'Empresa'); const customerId = identifier(request.data.customerId,'Cliente');
  const day = dayValue(request.data.day); const items = selection(request.data.items);
  const excludeId = request.data.appointmentId == null ? null : identifier(request.data.appointmentId, 'Agendamento');
  const requestedProfessional = request.data.professionalId == null ? null : identifier(request.data.professionalId,'Profissional');
  return db.runTransaction(async (tx) => {
    const access = await teamAccess(tx,db,tenantId,uid,schedulingRoles);
    refusePausedBooking(access);
    let bookedPets = [];
    if (excludeId) {
      const current = await tx.get(db.doc(`tenants/${tenantId}/appointments/${excludeId}`));
      if (!current.exists || current.get('customerId') !== customerId || !['REQUESTED','CONFIRMED'].includes(current.get('status'))) throw new HttpsError('permission-denied', 'Agendamento indisponível para remarcação.');
      bookedPets = executionItems(current.data()).map((item) => item.pet?.id);
    }
    const booking = await bookingData(tx,db,tenantId,uid,access,customerId,items);
    // Times of an appointment already booked can still be read; saving a new
    // time refuses the pets the petshop no longer serves.
    refuseUnservedPets(booking, access, items.map((item) => item.petId).filter((id) => !bookedPets.includes(id)));
    const doc = await tx.get(dayRef(db,tenantId,day)); const state = await reservationState(tx,db,tenantId,doc);
    const slots = [];
    for (let start=0;start+booking.durationMinutes<=1440;start+=booking.policy.slotMinutes) {
      const timestamp = zonedInstant(day,start,booking.policy.timeZone);
      if (timestamp == null || timestamp <= Date.now()) continue;
      for (const professional of booking.professionals) {
        if (requestedProfessional && requestedProfessional !== professional.id) continue;
        if (professionalAvailable(booking,professional,day,state,start,start+booking.durationMinutes,excludeId)) {
          slots.push({ startsAt:new Date(timestamp).toISOString(), label:timeLabel(start), professionalId:professional.id, professionalName:professional.get('name') });
        }
      }
    }
    return { slots, serviceQuote:serviceQuote(booking.items), timeZone:booking.policy.timeZone, durationMinutes:booking.durationMinutes, priceCents:booking.priceCents };
  });
});

export const saveAppointment = onCall(options, async (request) => {
  object(request.data,['tenantId','requestId','appointmentId','customerId','startsAt','items','professionalId','notes','tutorNotes','transportQuoteId','expectedPriceCents','expectedDurationMinutes','expectedServices'],'Pedido');
  const appointmentId = identifier(request.data.appointmentId,'Agendamento'); const customerId=identifier(request.data.customerId,'Cliente');
  const startsAt = text(request.data.startsAt,'Horário',40,20); const timestamp = Date.parse(startsAt);
  if (!Number.isFinite(timestamp)) invalid('Horário inválido.');
  const items = selection(request.data.items); const notes = text(request.data.notes ?? '','Observações',2000);
  const tutorNotes = text(request.data.tutorNotes ?? '','Orientações do tutor',500);
  // An absent field keeps the stored text; the hash distinguishes absent from empty.
  const sentNotes=Object.hasOwn(request.data,'notes'),sentTutorNotes=Object.hasOwn(request.data,'tutorNotes');
  const professionalId = request.data.professionalId == null ? null : identifier(request.data.professionalId,'Profissional');
  const expectedServices=normalizeServiceQuote(request.data.expectedServices);
  const expectedPriceCents=request.data.expectedPriceCents??null,expectedDurationMinutes=request.data.expectedDurationMinutes??null;
  return teamCommand(request,'saveAppointment',{appointmentId,customerId,startsAt,items,professionalId,notes:sentNotes?notes:null,tutorNotes:sentTutorNotes?tutorNotes:null,expectedPriceCents,expectedDurationMinutes,expectedServices,...(request.data.transportQuoteId?{transportQuoteId:request.data.transportQuoteId}:{})},async ({db,tx,tenantId,uid,access}) => {
    if(timestamp<=Date.now())invalid('Escolha um horário futuro.');
    const ref=db.doc(`tenants/${tenantId}/appointments/${appointmentId}`); const existing=await tx.get(ref);
    if (existing.exists && !['REQUESTED','CONFIRMED'].includes(existing.get('status'))) throw new HttpsError('failed-precondition','Este agendamento não pode mais ser editado.');
    if (existing.exists && existing.get('customerId') !== customerId) invalid('Não é possível trocar o cliente do agendamento.');
    if (!existing.exists || existing.get('startsAt')?.toMillis?.() !== timestamp) refusePausedBooking(access);
    const booking=await bookingData(tx,db,tenantId,uid,access,customerId,items);
    const bookedPets=existing.exists?executionItems(existing.data()).map((item)=>item.pet?.id):[];
    const newTime=!existing.exists||existing.get('startsAt')?.toMillis?.()!==timestamp;
    refuseUnservedPets(booking,access,items.map((item)=>item.petId).filter((id)=>newTime||!bookedPets.includes(id)));
    // Each voice owns its field, decided per field: team roles write notes and only the
    // tutor of this customer writes tutorNotes, so a manager who is also the tutor keeps both.
    const roles=access.member.get('roles');
    const team=roles.some((role)=>['MANAGER','ATTENDANT'].includes(role));
    const ownTutor=roles.includes('TUTOR')&&booking.tutorUid===uid&&access.member.get('customerId')===customerId;
    const voices={notes:team&&sentNotes?notes:existing.get('notes')??'',tutorNotes:ownTutor&&sentTutorNotes?tutorNotes:existing.get('tutorNotes')??''};
    if(expectedPriceCents!==booking.priceCents||expectedDurationMinutes!==booking.durationMinutes||!quoteMatches(expectedServices,booking.items))throw new HttpsError('failed-precondition','Os valores ou a duração dos serviços mudaram. Revise o resumo e confirme novamente.',{reason:'SERVICE_QUOTE_CHANGED',priceCents:booking.priceCents,durationMinutes:booking.durationMinutes,items:booking.items.map(item=>({petId:item.pet.id,services:item.services}))});
    const local=civil(timestamp,booking.policy.timeZone); const end=local.minute+booking.durationMinutes;
    if (timestamp % 60000 !== 0 || end>1440) invalid('Horário ou duração inválidos.');
    const currentDay=dayRef(db,tenantId,local.day); const previousDay=existing.exists ? existing.get('day') : null;
    const refs=[currentDay,...(previousDay && previousDay!==local.day ? [dayRef(db,tenantId,previousDay)]:[])];
    const dayDocs=await tx.getAll(...refs); const state=await reservationState(tx,db,tenantId,dayDocs[0]);
    const professional=booking.professionals.find((doc) => (!professionalId || doc.id===professionalId) && professionalAvailable(booking,doc,local.day,state,local.minute,end,appointmentId));
    if (!professional) throw new HttpsError('already-exists','Horário indisponível. Atualize os horários e escolha outro.');
    if (Object.keys(state.reservations ?? {}).length >= 500 && !state.reservations?.[appointmentId]) throw new HttpsError('resource-exhausted','Limite de reservas deste dia atingido.');
    const preparedTransport=await prepareBookingTransport(tx,db,tenantId,uid,access,request.data.transportQuoteId??null,existing,appointmentId,booking,startsAt,new Date(timestamp+booking.durationMinutes*60000).toISOString());
    const value={...(preparedTransport?.summary?{transport:preparedTransport.summary}:{}),customerId,customer:booking.customer,tutorUid:booking.tutorUid,items:booking.items.map(item=>({...item,execution:{status:existing.exists?existing.get('status'):'CONFIRMED',history:[]}})), executionVersion:1, startsAt:Timestamp.fromMillis(timestamp),endsAt:Timestamp.fromMillis(timestamp+booking.durationMinutes*60000),
      day:local.day,localStartsAt:`${local.day}T${timeLabel(local.minute)}:00`,timeZone:booking.policy.timeZone,professionalId:professional.id,professional:professional.get('name'),professionalUid:professional.get('authUid') ?? null,
      durationMinutes:booking.durationMinutes,priceCents:booking.priceCents,history:existing.get('history')??[{status:'CONFIRMED',at:new Date().toISOString()}],status:existing.exists ? existing.get('status'):'CONFIRMED',...voices,...metadata(uid,existing.exists)};
    [value.recordNumber] = await allocateRecordNumbers(tx, db, tenantId, [{type:'appointments',id:appointmentId,recordNumber:existing.get('recordNumber')}]);
    writeBookingTransport(tx,preparedTransport,appointmentId,uid);
    tx.set(ref,value,{merge:true});
    tx.set(currentDay,{...state,reservations:{...state.reservations,[appointmentId]:{start:local.minute,end,professionalId:professional.id,customerId,petIds:items.map(item=>item.petId)}}});
    if (dayDocs.length>1) { const old=dayDocs[1].data() ?? {}; const reservations={...old.reservations};delete reservations[appointmentId];tx.set(refs[1],{...old,reservations}); }
    const moved=existing.exists&&(existing.get('startsAt')?.toMillis?.()!==timestamp||existing.get('professionalId')!==professional.id);
    const when=noticeDate(value.localStartsAt),pets=petNames(booking.items),notices=[];
    if(!existing.exists||moved){
      const type=existing.exists?'APPOINTMENT_RESCHEDULED':'APPOINTMENT_CREATED';
      notices.push({role:'TUTOR',targetUid:booking.tutorUid,type,title:existing.exists?'Agendamento remarcado':'Novo agendamento',text:`${pets} · ${when}`,appointmentId});
      notices.push({role:'PROFESSIONAL',targetUid:value.professionalUid,type,title:existing.exists?'Atendimento remarcado':'Novo atendimento na sua agenda',text:`${pets} · ${when}`,appointmentId});
      if(existing.exists&&existing.get('professionalUid')&&existing.get('professionalUid')!==value.professionalUid)notices.push({role:'PROFESSIONAL',targetUid:existing.get('professionalUid'),type:'APPOINTMENT_REASSIGNED',title:'Atendimento saiu da sua agenda',text:`${pets} · ${noticeDate(existing.get('localStartsAt'))}`,appointmentId});
      if(!team)notices.push({role:'TEAM',type,title:existing.exists?'Tutor remarcou um agendamento':'Tutor fez um agendamento',text:`${booking.customer.name} · ${pets} · ${when}`,appointmentId});
    }
    if(preparedTransport?.rows?.length)notices.push({role:'TEAM',type:'TRANSPORT_REQUESTED',title:'Pedido de transporte do tutor',text:`${booking.customer.name} · ${pets} · ${when}`,appointmentId});
    notify(tx,db,tenantId,uid,notices);
    const saved={id:appointmentId,...value,startsAt:new Date(timestamp).toISOString(),endsAt:new Date(timestamp+booking.durationMinutes*60000).toISOString(),createdAt:null,updatedAt:null,createdBy:null,updatedBy:null};
    return {appointment:team?saved:tutorView(saved)};
  },schedulingRoles);
});

export const updateAppointmentNotes = onCall(options, async request => {
  object(request.data, ['tenantId','requestId','appointmentId','notes'], 'Observações');
  const appointmentId = identifier(request.data.appointmentId, 'Agendamento');
  const notes = text(request.data.notes ?? '', 'Observações', 2000);
  return teamCommand(request, 'updateAppointmentNotes', {appointmentId,notes}, async ({db,tx,tenantId,uid}) => {
    const ref = db.doc(`tenants/${tenantId}/appointments/${appointmentId}`), previous = await tx.get(ref);
    if (!previous.exists || !liveStatuses.includes(previous.get('status'))) throw new HttpsError('failed-precondition', 'Este atendimento não permite alterar observações.');
    tx.update(ref, {notes,...metadata(uid,true)});
    return {appointment:{...jsonAppointment(previous),notes}};
  }, ['MANAGER','ATTENDANT']);
});

const transitions={REQUESTED:['CONFIRMED','CANCELLED'],CONFIRMED:['PET_RECEIVED','CANCELLED','NO_SHOW'],PET_RECEIVED:['IN_PROGRESS','CANCELLED'],IN_PROGRESS:['COMPLETED']};
export const updateAppointmentStatus = onCall(options,async (request) => {
  object(request.data,['tenantId','requestId','appointmentId','status','petId'],'Pedido');
  const appointmentId=identifier(request.data.appointmentId,'Agendamento');const status=text(request.data.status,'Situação',30,1);
  const petId=request.data.petId==null?null:identifier(request.data.petId,'Pet');
  return teamCommand(request,'updateAppointmentStatus',{appointmentId,status,...(petId?{petId}:{})},async ({db,tx,tenantId,uid,access}) => {
    const ref=db.doc(`tenants/${tenantId}/appointments/${appointmentId}`);const previous=await tx.get(ref);
    if (!previous.exists) throw new HttpsError('not-found','Agendamento não encontrado.');
    const roles=access.member.get('roles'); const team=roles.some((role)=>['MANAGER','ATTENDANT'].includes(role));
    // The linked customer record decides the tutor, also for appointments
    // the team created before the account was linked.
    const tutorUid=await customerTutorUid(tx,db,tenantId,previous.get('customerId'));
    const ownsRecord=roles.includes('TUTOR')&&tutorUid===uid&&access.member.get('customerId')===previous.get('customerId');
    if (!team) {
      const ownTutorCancellation=ownsRecord&&status==='CANCELLED'&&['REQUESTED','CONFIRMED'].includes(previous.get('status'));
      const assignedProfessional=roles.includes('PROFESSIONAL')&&previous.get('professionalUid')===uid&&['IN_PROGRESS','COMPLETED'].includes(status);
      if(!ownTutorCancellation&&!assignedProfessional)throw new HttpsError('permission-denied','Operação não permitida para esta conta.');
    }
    const individual=['IN_PROGRESS','COMPLETED'].includes(status);
    if(petId&&!individual)invalid('Ação individual inválida.');
    if (!individual && !transitions[previous.get('status')]?.includes(status)) throw new HttpsError('failed-precondition','Transição de situação inválida.');
    if (['IN_PROGRESS','COMPLETED'].includes(status) && !roles.includes('MANAGER') && previous.get('professionalUid')!==uid) throw new HttpsError('permission-denied','Somente gerente ou profissional atribuído pode executar o atendimento.');
    const at=new Date().toISOString();
    const patch=individual?changePetExecution(previous.data(),petId,status,uid,at):{status,items:executionItems(previous.data()).map(item=>({...item,execution:{...item.execution,status,history:[...(item.execution.history??[]),{status,at,actorUid:uid}]}}))};
    const schedule=dayRef(db,tenantId,previous.get('day'));const day=await tx.get(schedule);
    const cancelled=['CANCELLED','NO_SHOW'].includes(status)?await prepareTransportCancellation(tx,db,tenantId,appointmentId):null;
    const history=[...(previous.get('history')??[]),...(patch.status!==previous.get('status')?[{status:patch.status,at,actorUid:uid}]:[])];
    if(cancelled)writeTransportCancellation(tx,cancelled,uid);
    tx.update(ref,{...patch,executionVersion:1,history,...metadata(uid,true)});
    if (!liveStatuses.includes(patch.status)) {const state=day.data() ?? {};const reservations={...state.reservations};delete reservations[appointmentId];tx.set(schedule,{...state,reservations});}
    if(patch.status!==previous.get('status')){
      const when=noticeDate(previous.get('localStartsAt')),pets=petNames(previous.get('items')),summary=`${pets} · ${when}`,notices=[];
      if(['CANCELLED','NO_SHOW'].includes(patch.status)){
        const title=patch.status==='CANCELLED'?'Agendamento cancelado':'Não comparecimento registrado';
        notices.push({role:'TUTOR',targetUid:tutorUid,type:'APPOINTMENT_CANCELLED',title,text:summary,appointmentId});
        notices.push({role:'PROFESSIONAL',targetUid:previous.get('professionalUid'),type:'APPOINTMENT_CANCELLED',title,text:summary,appointmentId});
        if(!team)notices.push({role:'TEAM',type:'APPOINTMENT_CANCELLED',title:'Tutor cancelou um agendamento',text:`${previous.get('customer')?.name??'Cliente'} · ${summary}`,appointmentId});
        for(const job of cancelled?.jobs??[])notices.push({role:'DRIVER',targetUid:job.get('driverUid'),type:'TRANSPORT_CANCELLED',title:'Transporte cancelado',text:`${pets} · agendamento cancelado`,transportId:job.id});
      }else if(['PET_RECEIVED','IN_PROGRESS','COMPLETED'].includes(patch.status)){
        const titles={PET_RECEIVED:'Pet recebido no petshop',IN_PROGRESS:'Atendimento iniciado',COMPLETED:'Atendimento concluído'};
        notices.push({role:'TUTOR',targetUid:tutorUid,type:'APPOINTMENT_STATUS',title:titles[patch.status],text:summary,appointmentId});
      }
      notify(tx,db,tenantId,uid,notices);
    }
    const changed={...jsonAppointment(previous),...patch,executionVersion:1,history,createdAt:null,updatedAt:null};
    return {appointment:roles.some((role)=>['MANAGER','ATTENDANT','PROFESSIONAL'].includes(role))?changed:tutorView(changed)};
  },['MANAGER','ATTENDANT','PROFESSIONAL','TUTOR'],async({db,tx,tenantId,uid,access})=>{
    const current=await tx.get(db.doc(`tenants/${tenantId}/appointments/${appointmentId}`));
    const roles=access.member.get('roles');
    const execution=['IN_PROGRESS','COMPLETED'].includes(status);
    if(!current.exists || (execution ? !roles.includes('MANAGER')&&current.get('professionalUid')!==uid : !roles.some(role=>['MANAGER','ATTENDANT'].includes(role))&&!(roles.includes('TUTOR')&&access.member.get('customerId')===current.get('customerId')&&status==='CANCELLED')))
      throw new HttpsError('permission-denied','Operação não permitida para esta conta.');
  });
});

export const getTeamResource=onCall(options,async(request)=>{
  const db=localBackend();const uid=await actor(request);
  object(request.data,['tenantId','resource','cursor'],'Consulta');const tenantId=identifier(request.data.tenantId,'Empresa');
  const resource=request.data.resource;if(!['appointments','professionals','blocks'].includes(resource)) invalid('Recurso inválido.');
  const cursor=request.data.cursor==null?null:identifier(request.data.cursor,'Página');
  return db.runTransaction(async(tx)=>{const access=await teamAccess(tx,db,tenantId,uid);let query=db.collection(`tenants/${tenantId}/${resource}`).orderBy(FieldPath.documentId()).limit(100);if(cursor)query=query.startAfter(cursor);const page=await tx.get(query);const policy=resource==='blocks'?await tx.get(policyRef(db,tenantId)):null;
    return {items:page.docs.map((doc)=>resource==='appointments'?jsonAppointment(doc):resource==='professionals'?publicProfessional(doc):{id:doc.id,...doc.data(),...(resource==='blocks'?{canEdit:canEditBlock(access.member.get('roles'),uid,doc.data(),policy?.get('timeZone')??'America/Cuiaba'),editableUntil:new Date(blockStartsAt(doc.data(),policy?.get('timeZone')??'America/Cuiaba')).toISOString()} : {}),createdAt:null,updatedAt:null}),nextCursor:page.size===100?page.docs.at(-1).id:null};});
});

export const getSchedulingPolicy=onCall(options,async(request)=>{
  const db=localBackend();const uid=await actor(request);object(request.data,['tenantId'],'Consulta');const tenantId=identifier(request.data.tenantId,'Empresa');
  return db.runTransaction(async(tx)=>{await teamAccess(tx,db,tenantId,uid);const doc=await tx.get(policyRef(db,tenantId));if(doc.exists)return{configured:true,timeZone:doc.get('timeZone'),slotMinutes:doc.get('slotMinutes'),days:jsonDays(doc.get('days'))};
    // Not configured yet: suggest the zone of the state registered for the company.
    const tenant=await tx.get(db.doc(`tenants/${tenantId}`));return{configured:false,timeZone:stateTimeZone(tenant.get('state'))??defaultTimeZone};});
});
export const saveSchedulingPolicy=onCall(options,async(request)=>{
  object(request.data,['tenantId','requestId','days','timeZone','slotMinutes'],'Pedido');const days=weekDays(request.data.days);const zone=timeZone(request.data.timeZone);const slotMinutes=request.data.slotMinutes;
  if(!Number.isSafeInteger(slotMinutes)||slotMinutes<5||slotMinutes>120||slotMinutes%5)invalid('Intervalo deve ser múltiplo de cinco entre 5 e 120 minutos.');
  return teamCommand(request,'saveSchedulingPolicy',{days,zone,slotMinutes},async({db,tx,tenantId,uid})=>{const ref=policyRef(db,tenantId);const old=await tx.get(ref);tx.set(ref,{days,timeZone:zone,slotMinutes,...metadata(uid,old.exists)});return{configured:true,timeZone:zone,slotMinutes,days:jsonDays(days)};},['MANAGER']);
});

export const saveProfessional=onCall(options,async request=>{
  object(request.data,['tenantId','requestId','professionalId','professional'],'Cadastro profissional');
  const professionalId=identifier(request.data.professionalId,'Profissional'), input=request.data.professional;
  object(input,['name','email','specialty','active','availability'],'Profissional');
  const availability=input.availability==null?null:weekDays(input.availability);
  return teamCommand(request,'saveProfessional',{professionalId,professional:input},async({db,tx,tenantId,uid})=>{
    const ref=db.doc('tenants/'+tenantId+'/professionals/'+professionalId), previous=await tx.get(ref);
    if(!previous.exists)throw new HttpsError('failed-precondition','O profissional deve preencher os próprios dados pelo convite.');
    if(input.name!=null&&input.name!==previous.get('name') || input.email || input.specialty!=null&&input.specialty!==previous.get('specialty') || input.active!=null&&input.active!==previous.get('active'))
      throw new HttpsError('permission-denied','Os dados pessoais e profissionais só podem ser alterados pelo titular. Para retirar o acesso, use Desvincular.');
    if(previous.get('authUid')) { const member=await tx.get(db.doc('tenants/'+tenantId+'/members/'+previous.get('authUid'))); requireEditableWorkforceMember(member.data()); }
    const [recordNumber]=await allocateRecordNumbers(tx,db,tenantId,[{type:'professionals',id:professionalId,recordNumber:previous.get('recordNumber')}]);
    tx.update(ref,{recordNumber,...(availability==null?{}:{availability}),...metadata(uid,true)});
    return{professional:{...publicProfessional(previous),recordNumber,...(availability==null?{}:{availability})}};
  },['MANAGER']);
});

async function blockAccess(tx, db, tenantId, uid, access, blockId, proposed) {
  const ref = db.doc(`tenants/${tenantId}/blocks/${blockId}`);
  const [old, policy] = await tx.getAll(ref, policyRef(db, tenantId));
  const zone = policy.get('timeZone') ?? 'America/Cuiaba';
  authorizeBlock(access.member.get('roles'), uid, old.exists ? old.data() : null, proposed, zone);
  return {ref, old, zone};
}
export const saveBlock=onCall(options,async(request)=>{
  object(request.data,['tenantId','requestId','blockId','block'],'Pedido');const blockId=identifier(request.data.blockId,'Bloqueio');const input=request.data.block;object(input,['date','start','end','reason','fullDay'],'Bloqueio');
  const date=dayValue(input.date);if(typeof input.fullDay!=='boolean')invalid('Dia inteiro inválido.');const start=input.fullDay?0:minute(input.start);const end=input.fullDay?1440:minute(input.end);if(start>=end)invalid('Período inválido.');
  const value={date,start:timeLabel(start),end:input.fullDay?'23:59':timeLabel(end),reason:text(input.reason,'Motivo',500,1),fullDay:input.fullDay};
  return teamCommand(request,'saveBlock',{blockId,...value},async({db,tx,tenantId,uid,access})=>{
    const {ref,old,zone}=await blockAccess(tx,db,tenantId,uid,access,blockId,value);
    const refs=[dayRef(db,tenantId,date),...(old.exists&&old.get('date')!==date?[dayRef(db,tenantId,old.get('date'))]:[])];const docs=await tx.getAll(...refs);const state=docs[0].data()??{};
    if(Object.keys(state.blocks??{}).length>=500&&!state.blocks?.[blockId])throw new HttpsError('resource-exhausted','Limite de bloqueios deste dia atingido.');
    const conflicts=Object.entries(state.reservations??{}).filter(([,reservation])=>overlaps({start,end},reservation));
    if(conflicts.length){const periods=conflicts.slice(0,10).map(([,r])=>`${timeLabel(r.start)}–${timeLabel(r.end)}`).join(', ');throw new HttpsError('already-exists',`Bloqueio não salvo: ${conflicts.length} agendamento(s) em conflito em ${date}: ${periods}${conflicts.length>10?'…':''}. Resolva os agendamentos na Agenda antes de bloquear. Nenhum agendamento foi alterado.`,{appointmentIds:conflicts.map(([id])=>id)});}
    const [recordNumber] = await allocateRecordNumbers(tx, db, tenantId, [{type:'blocks',id:blockId,recordNumber:old.get('recordNumber')}]);
    const saved={...old.data(),...value,recordNumber,...metadata(uid,old.exists)};
    tx.set(ref,saved);tx.set(refs[0],{...state,blocks:{...state.blocks,[blockId]:{start,end}}});if(docs.length>1){const previous=docs[1].data()??{};const blocks={...previous.blocks};delete blocks[blockId];tx.set(refs[1],{...previous,blocks});}
    return{block:{id:blockId,...saved,canEdit:canEditBlock(access.member.get('roles'),uid,{...saved,createdBy:old.get('createdBy')??uid},zone),editableUntil:new Date(blockStartsAt(value,zone)).toISOString(),createdAt:null,updatedAt:null}};
  },['MANAGER','ATTENDANT'],async({db,tx,tenantId,uid,access})=>{await blockAccess(tx,db,tenantId,uid,access,blockId,value);});
});
export const removeBlock=onCall(options,async(request)=>{
  object(request.data,['tenantId','requestId','blockId'],'Pedido');const blockId=identifier(request.data.blockId,'Bloqueio');
  return teamCommand(request,'removeBlock',{blockId},async({db,tx,tenantId,uid,access})=>{
    const {ref,old}=await blockAccess(tx,db,tenantId,uid,access,blockId,null);if(!old.exists)return{removed:true};
    const schedule=dayRef(db,tenantId,old.get('date'));const day=await tx.get(schedule);const state=day.data()??{};const blocks={...state.blocks};delete blocks[blockId];tx.delete(ref);tx.set(schedule,{...state,blocks});return{removed:true};
  },['MANAGER','ATTENDANT'],async({db,tx,tenantId,uid,access})=>{await blockAccess(tx,db,tenantId,uid,access,blockId,null);});
});
