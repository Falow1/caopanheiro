import { driverEligible } from './workforce_policy.js';
import {requireTransportSchedule} from './transport_schedule.js';
import {prepareTransportLeg,writeTransportLeg} from './transport_custody.js';
import {appointmentTransportRows,prepareTransportReschedule} from './transport_rescheduling.js';
import {HttpsError} from 'firebase-functions/v2/https';
import {onCall} from './callable.js';
import {Timestamp} from 'firebase-admin/firestore';
import {actor,identifier,invalid,localBackend,object,options,teamAccess,text,digest} from './runtime.js';
import { brazilPhone } from './contact_policy.js';
import {teamCommand,metadata} from './team_commands.js';
import {allocateRecordNumbers} from './record_numbers.js';
import {conflictPreview,requireConflictAcknowledgement,scheduleInput,scheduleInstant,scheduleKey,transportClock,transportZone} from './transport_operations.js';
import {notify,noticeDate,petNames} from './notices.js';
import {tutorOwnsCustomer} from './tutor_access.js';
import {tenantFeature} from './access_policy.js';
import {defaultTimeZone,localLabel,stateTimeZone} from './calendar.js';
import {purgeAt,retention} from './retention.js';
const legLabel=type=>type==='PICKUP'?'Coleta':'Retorno';

const policyRef=(db,tenant)=>db.doc(`tenants/${tenant}/settings/transport`);
export function point(v){object(v,['lat','lng'],'Ponto');if(!Number.isFinite(v.lat)||!Number.isFinite(v.lng)||v.lat< -90||v.lat>90||v.lng< -180||v.lng>180)invalid('Marque um ponto válido no mapa.');return {lat:v.lat,lng:v.lng};}
export function place(v){object(v,['name','street','district','phone','point'],'Local');return{name:text(v.name,'Contato',100,1),street:text(v.street,'Endereço e número',300,3),district:text(v.district,'Bairro/cidade',150,1),phone:brazilPhone(text(v.phone,'Telefone',32,8)),point:point(v.point)};}
function amount(v,label,max=100000){if(!Number.isSafeInteger(v)||v<0||v>max)invalid(label+' inválido.');return v;}
export function priceFor(meters,policy){if(!Number.isFinite(meters)||meters<0||meters>policy.maxDistanceKm*1000)throw new HttpsError('failed-precondition','Endereço fora da área de transporte.');return Math.max(policy.minimumCents,policy.baseCents+Math.ceil(meters*policy.perKmCents/1000));}
export function policyValue(v){object(v,['enabled','shop','baseCents','minimumCents','perKmCents','maxDistanceKm'],'Configuração');if(typeof v.enabled!=='boolean')invalid('Informe se o transporte está ativo.');const result={enabled:v.enabled,shop:place(v.shop),baseCents:amount(v.baseCents,'Valor base'),minimumCents:amount(v.minimumCents,'Mínimo'),perKmCents:amount(v.perKmCents,'Valor por km'),maxDistanceKm:amount(v.maxDistanceKm,'Limite de distância',100)};if(result.maxDistanceKm<1||result.enabled&&result.perKmCents<1)invalid('Informe valor por km e área de atendimento.');return result;}
async function authorized(request,roles,tutorRead=false){const db=localBackend(),uid=await actor(request),tenant=identifier(request.data.tenantId,'Empresa');const access=await db.runTransaction(tx=>teamAccess(tx,db,tenant,uid,roles,{tutorRead}));return{db,uid,tenant,access};}
export async function requireAttendantTransportEnabled(tx,db,tenantId,access){
 if(access.member.get('roles')?.includes('MANAGER'))return;
 const policy=await tx.get(policyRef(db,tenantId));
 if(policy.get('enabled')!==true)throw new HttpsError('failed-precondition','Novos transportes estão desativados. Solicite a ativação ao gestor.');
}
export const getTransportPolicy=onCall(options,async request=>{object(request.data,['tenantId'],'Consulta');const{db,tenant}=await authorized(request,['MANAGER','ATTENDANT','TUTOR']);const doc=await policyRef(db,tenant).get();return{policy:doc.exists?{...doc.data(),createdAt:null,updatedAt:null}:{enabled:false}};});
export const saveTransportPolicy=onCall(options,async request=>{object(request.data,['tenantId','requestId','policy'],'Configuração');const policy=policyValue(request.data.policy);return teamCommand(request,'saveTransportPolicy',policy,async({db,tx,tenantId,uid,access})=>{if(policy.enabled)if(!tenantFeature(access.subscription,'transport'))throw new HttpsError('failed-precondition','Transporte com entregador fica no plano Completo.',{reason:'PLAN_FEATURE'});const ref=policyRef(db,tenantId),old=await tx.get(ref);const value={...policy,version:(old.get('version')??0)+1};tx.set(ref,{...value,...metadata(uid,old.exists)});return{policy:value};},['MANAGER']);});

// One local process serializes user-triggered Nominatim searches; no autocomplete.
let lastSearch=0,searchQueue=Promise.resolve();
export const searchTransportAddress=onCall({...options,maxInstances:1,concurrency:1},async request=>{
 object(request.data,['tenantId','query'],'Busca');const{db}=await authorized(request,['MANAGER','ATTENDANT','TUTOR']);const query=text(request.data.query,'Endereço',300,5);
 const ref=db.doc(`mapSearchCache/${digest(query.toLocaleLowerCase('pt-BR'))}`),cached=await ref.get();if(cached.exists&&cached.get('expiresAt').toMillis()>Date.now())return{places:cached.get('places')};
 const task=searchQueue.then(async()=>{const wait=1100-(Date.now()-lastSearch);if(wait>0)await new Promise(resolve=>setTimeout(resolve,wait));lastSearch=Date.now();
  const endpoint=process.env.TRANSPORT_GEOCODER_URL??'https://nominatim.openstreetmap.org/search';const url=new URL(endpoint);url.search=new URLSearchParams({q:query,format:'jsonv2',limit:'5',countrycodes:'br'}).toString();
  const response=await fetch(url,{headers:{'User-Agent':'CaopanheiroLocal/42 (https://github.com/ho-Rafa/petshop-ecosystem)','Accept-Language':'pt-BR'},signal:AbortSignal.timeout(12000)});if(!response.ok)throw new Error('Geocoder unavailable');
  const rows=await response.json();if(!Array.isArray(rows))throw new Error('Invalid geocoder response');const places=rows.map(v=>({label:String(v.display_name).slice(0,500),point:point({lat:Number(v.lat),lng:Number(v.lon)})}));await ref.set({places,expiresAt:Timestamp.fromMillis(Date.now()+86400000),purgeAt:purgeAt(retention.mapCache)});return{places};
 });searchQueue=task.catch(()=>{});try{return await task;}catch{throw new HttpsError('unavailable','Busca de endereço indisponível. Tente novamente ou marque o ponto no mapa.');}
});
export async function roadDistance(origin,destination,fetcher=fetch){
 const base=process.env.TRANSPORT_ROUTER_URL??'https://router.project-osrm.org';
 try{const response=await fetcher(`${base}/route/v1/driving/${origin.lng},${origin.lat};${destination.lng},${destination.lat}?overview=false&alternatives=false&steps=false&radiuses=100;100`,{signal:AbortSignal.timeout(12000)});if(!response.ok)throw Error();const value=await response.json();if(value.code!=='Ok'||!Number.isFinite(value.routes?.[0]?.distance))throw Error();return Math.ceil(value.routes[0].distance);}catch{throw new HttpsError('unavailable','Não foi possível calcular a rota pelas ruas. Tente novamente; nenhuma taxa foi confirmada.');}
}
export const quoteTutorTransport=onCall(options,async request=>{
 object(request.data,['tenantId','pickup','returnTrip','location'],'Cotação');const {db,tenant,uid,access}=await authorized(request,['TUTOR']);if(!tenantFeature(access.subscription,'transport'))throw new HttpsError('failed-precondition','Transporte ainda não está disponível nesta empresa.',{reason:'PLAN_FEATURE'});
 if(typeof request.data.pickup!=='boolean'||typeof request.data.returnTrip!=='boolean'||!request.data.pickup&&!request.data.returnTrip)invalid('Escolha coleta ou retorno.');
 const location=place(request.data.location),policyDoc=await policyRef(db,tenant).get(),policy=policyDoc.data();if(!policy?.enabled)throw new HttpsError('failed-precondition','Transporte ainda não está disponível nesta empresa.');
 const legs=[];
 if(request.data.pickup){const meters=await roadDistance(location.point,policy.shop.point);legs.push({id:db.collection('identifiers').doc().id,type:'PICKUP',meters,feeCents:priceFor(meters,policy),origin:location,destination:policy.shop});}
 if(request.data.returnTrip){const meters=await roadDistance(policy.shop.point,location.point);legs.push({id:db.collection('identifiers').doc().id,type:'RETURN',meters,feeCents:priceFor(meters,policy),origin:policy.shop,destination:location});}
 const ref=db.collection(`tenants/${tenant}/transportQuotes`).doc(),expiresAt=new Date(Date.now()+15*60000).toISOString();const quote={id:ref.id,tutorUid:uid,policyVersion:policy.version,pricing:{baseCents:policy.baseCents,minimumCents:policy.minimumCents,perKmCents:policy.perKmCents},legs,totalCents:legs.reduce((n,l)=>n+l.feeCents,0),expiresAt,routeProvider:'OSRM-driving',createdAt:new Date().toISOString()};await ref.create({...quote,purgeAt:purgeAt(retention.quote)});return{quote};
});
export async function prepareBookingTransport(tx,db,tenantId,uid,access,quoteId,existing,appointmentId,booking,startsAt,endsAt){
 if(existing.exists){
  if(quoteId!=null)throw new HttpsError('failed-precondition','Uma remarcação não aceita nova cotação de transporte.');
  return prepareTransportReschedule(tx,db,tenantId,uid,access,existing,appointmentId,booking,startsAt,endsAt);
 }
 if(quoteId==null)return null;
 if(!access.member.get('roles').includes('TUTOR')||booking.tutorUid!==uid)throw new HttpsError('permission-denied','Cotação exclusiva do tutor responsável.');
 const ref=db.doc(`tenants/${tenantId}/transportQuotes/${identifier(quoteId,'Cotação')}`),doc=await tx.get(ref),policy=await tx.get(policyRef(db,tenantId));
 if(!doc.exists||doc.get('tutorUid')!==uid||doc.get('appointmentId')||Date.parse(doc.get('expiresAt'))<=Date.now()||!policy.get('enabled')||policy.get('version')!==doc.get('policyVersion'))throw new HttpsError('failed-precondition','Cotação vencida ou alterada. Calcule novamente a taxa.');
 const quote=doc.data();return{quoteRef:ref,summary:{quoteId,totalCents:quote.totalCents,pricing:quote.pricing,legs:quote.legs.map(l=>({id:l.id,type:l.type,meters:l.meters,feeCents:l.feeCents}))},rows:quote.legs.map(l=>({ref:db.doc(`tenants/${tenantId}/transportRequests/${l.id}`),value:{...l,appointmentId,customerId:booking.customer.id,tutorUid:uid,tenantId,appointmentStartsAt:startsAt,status:'REQUESTED',pets:booking.items.map(i=>i.pet),pricing:quote.pricing,requestedAt:new Date().toISOString()}}))};
}
export function writeBookingTransport(tx,prepared,appointmentId,uid){
 if(!prepared)return;
 if(prepared.reschedule){
  const now=new Date().toISOString();
  for(const row of prepared.moved){
   const history=[...(row.value.scheduleHistory??[]),{previous:row.doc.get('scheduledAt'),scheduledAt:row.value.scheduledAt,actorUid:uid,at:now}];
   tx.update(row.doc.ref,{scheduledAt:row.value.scheduledAt,...transportClock(row.value.scheduledAt,row.value.timeZone),scheduleHistory:history,...metadata(uid,true)});
  }
  for(const doc of prepared.requests){
   const job=prepared.moved.find(row=>row.doc.id===doc.get('transportId'));
   tx.update(doc.ref,{appointmentStartsAt:prepared.startsAt,...(job?{scheduledAt:job.value.scheduledAt,...transportClock(job.value.scheduledAt,job.value.timeZone)}:{}),...metadata(uid,true)});
  }
  return;
 }
 tx.update(prepared.quoteRef,{appointmentId});for(const row of prepared.rows)tx.create(row.ref,{...row.value,...metadata(uid,false)});
}
export const getTransportRequests=onCall(options,async request=>{object(request.data,['tenantId','cursor'],'Consulta');const{db,tenant}=await authorized(request,['MANAGER','ATTENDANT']);let query=db.collection(`tenants/${tenant}/transportRequests`).orderBy('__name__').limit(50);if(request.data.cursor)query=query.startAfter(identifier(request.data.cursor,'Página'));const docs=await query.get();
 // The team chooses the time on the company clock, so the appointment is shown on it too.
 const[schedule,company]=await db.getAll(db.doc(`tenants/${tenant}/settings/scheduling`),db.doc(`tenants/${tenant}`));const zone=schedule.get('timeZone')??stateTimeZone(company.get('state'))??defaultTimeZone;
 const local=at=>Number.isFinite(Date.parse(at))?localLabel(Date.parse(at),zone):null;
 return{items:docs.docs.map(d=>({id:d.id,...d.data(),appointmentLocalStartsAt:local(d.get('appointmentStartsAt')),createdAt:null,updatedAt:null})),nextCursor:docs.size===50?docs.docs.at(-1).id:null};});
export const decideTransportRequest=onCall(options,async request=>{
 object(request.data,['tenantId','requestId','transportRequestId','accept','driverUid','scheduledAt','localScheduledAt','reason','conflictAcknowledgement'],'Decisão');
 const id=identifier(request.data.transportRequestId,'Pedido'),accept=request.data.accept;if(typeof accept!=='boolean')invalid('Decisão inválida.');
 const reason=text(request.data.reason??'','Motivo',1000,accept?0:3),driverUid=accept?identifier(request.data.driverUid,'Entregador'):null,schedule=accept?scheduleInput(request.data,false):null;
 return teamCommand(request,'decideTransportRequest',{id,accept,reason,driverUid,...(schedule?scheduleKey(schedule):{scheduledAt:null}),token:request.data.conflictAcknowledgement??null},async({db,tx,tenantId,uid,access:argumentsAccess})=>{
  const ref=db.doc(`tenants/${tenantId}/transportRequests/${id}`),doc=await tx.get(ref);if(!doc.exists||doc.get('status')!=='REQUESTED')throw new HttpsError('failed-precondition','Pedido já tratado. Atualize.');
  const appointment=await tx.get(db.doc(`tenants/${tenantId}/appointments/${doc.get('appointmentId')}`));if(!appointment.exists||['CANCELLED','NO_SHOW'].includes(appointment.get('status')))throw new HttpsError('failed-precondition','Agendamento indisponível.');
  if(!accept){tx.update(ref,{status:'REJECTED',reason,decidedAt:new Date().toISOString(),...metadata(uid,true)});
   notify(tx,db,tenantId,uid,[{role:'TUTOR',targetUid:doc.get('tutorUid'),type:'TRANSPORT_DECIDED',title:'Pedido de transporte não confirmado',text:`${legLabel(doc.get('type'))} · ${reason}`,appointmentId:appointment.id}]);
   return{status:'REJECTED'};}
  await requireAttendantTransportEnabled(tx,db,tenantId,argumentsAccess);
  const zone=transportZone(appointment.data()),scheduledAt=scheduleInstant(schedule,zone);
  if(Date.parse(scheduledAt)<=Date.now())invalid('Escolha um horário futuro.');
  requireTransportSchedule(doc.get('type'),scheduledAt,appointment.data());
  const driver=await tx.get(db.doc(`tenants/${tenantId}/members/${driverUid}`));if(!driverEligible(driver.data()))throw new HttpsError('permission-denied','Entregador indisponível.');
  const preview=await conflictPreview(tx,db,tenantId,driverUid,scheduledAt,null);requireConflictAcknowledgement(preview,request.data.conflictAcknowledgement??null);
  const transportRef=db.collection(`tenants/${tenantId}/transports`).doc();
  const leg=await prepareTransportLeg(tx,db,tenantId,appointment.id,doc.get('type'),doc.get('pets'),transportRef.id);
  const[recordNumber]=await allocateRecordNumbers(tx,db,tenantId,[{type:'transports',id:transportRef.id}]);
  const transport={id:transportRef.id,recordNumber,tenantId,appointmentId:appointment.id,appointmentNumber:appointment.get('recordNumber')??null,transportRequestId:id,tutorUid:doc.get('tutorUid'),customerId:doc.get('customerId'),driverUid,type:doc.get('type'),origin:doc.get('origin'),destination:doc.get('destination'),pets:doc.get('pets'),feeCents:doc.get('feeCents'),distanceMeters:doc.get('meters'),status:'ASSIGNED',scheduledAt:new Date(scheduledAt).toISOString(),...transportClock(scheduledAt,zone),estimatedDurationMinutes:null,operationalVersion:2,notes:'',events:[{status:'ASSIGNED',createdAt:new Date().toISOString(),actor:uid}],incidents:[],startedAt:null,collectedAt:null,deliveredAt:null};
  writeTransportLeg(tx,leg);tx.create(transportRef,{...transport,...metadata(uid,false)});tx.update(ref,{status:'CONFIRMED',transportId:transportRef.id,scheduledAt:transport.scheduledAt,localScheduledAt:transport.localScheduledAt,timeZone:zone,decidedAt:new Date().toISOString(),...metadata(uid,true)});
  const names=petNames(doc.get('pets'));
  notify(tx,db,tenantId,uid,[
   {role:'TUTOR',targetUid:doc.get('tutorUid'),type:'TRANSPORT_DECIDED',title:`${legLabel(doc.get('type'))} confirmada pela equipe`.replace('Retorno confirmada','Retorno confirmado'),text:names,appointmentId:appointment.id},
   {role:'DRIVER',targetUid:driverUid,type:'TRANSPORT_ASSIGNED',title:'Novo transporte atribuído',text:`${legLabel(doc.get('type'))} · ${names}`,transportId:transportRef.id}]);
  return{status:'CONFIRMED',transportId:transportRef.id};
 });
});
export const getTutorTransportTracking=onCall(options,async request=>{
 object(request.data,['tenantId','appointmentId'],'Consulta');const {db,tenant,uid}=await authorized(request,['TUTOR'],true);const id=identifier(request.data.appointmentId,'Agendamento');
 return db.runTransaction(async tx=>{
  const currentAccess=await teamAccess(tx,db,tenant,uid,['TUTOR'],{tutorRead:true});const appointment=await tx.get(db.doc(`tenants/${tenant}/appointments/${id}`));
  if(!appointment.exists||!await tutorOwnsCustomer(tx,db,tenant,uid,currentAccess,appointment.get('customerId')))throw new HttpsError('permission-denied','Agendamento não pertence a esta conta.');
  const rows=await appointmentTransportRows(tx,db,tenant,id);const byId=new Map(rows.jobs.map(job=>[job.id,job]));
  // Company wall clock, from the appointment zone, also for older records.
  const zone=transportZone(appointment.data()),clock=at=>at?transportClock(at,zone):{localScheduledAt:null,timeZone:zone};
  // Steps and an incident flag only: incident text is written for the team.
  const progress=job=>({transportStatus:job?job.get('status'):null,deliveredAt:job?job.get('deliveredAt')??null:null,openIncident:job?(job.get('incidents')??[]).some(incident=>incident.status!=='RESOLVED'):false,events:job?(job.get('events')??[]).map(e=>({status:e.status,createdAt:e.createdAt})):[]});
  const requested=rows.requests.map(doc=>{const v=doc.data();return{id:doc.id,source:'TUTOR',type:v.type,status:v.status,reason:v.reason??'',feeCents:v.feeCents,meters:v.meters,origin:v.origin,destination:v.destination,scheduledAt:v.scheduledAt??null,...clock(v.scheduledAt),...progress(byId.get(v.transportId))};});
  const linked=new Set(rows.requests.map(doc=>doc.get('transportId')).filter(Boolean));
  // Transports scheduled directly by the team have no request and no fee quote.
  const direct=rows.jobs.filter(job=>!job.get('transportRequestId')&&!linked.has(job.id)).map(job=>({id:job.id,source:'TEAM',type:job.get('type'),status:job.get('status')==='CANCELLED'?'CANCELLED':'CONFIRMED',reason:'',feeCents:job.get('feeCents')??null,meters:job.get('distanceMeters')??null,origin:job.get('origin'),destination:job.get('destination'),scheduledAt:job.get('scheduledAt')??null,...clock(job.get('scheduledAt')),...progress(job)}));
  return{items:[...requested,...direct],checkedAt:new Date().toISOString()};});
});
// Transport asked by the tutor after booking, or again after a refusal.
export const requestTutorTransport=onCall(options,async request=>{
 object(request.data,['tenantId','requestId','appointmentId','transportQuoteId'],'Pedido');
 const appointmentId=identifier(request.data.appointmentId,'Agendamento'),quoteId=identifier(request.data.transportQuoteId,'Cotação');
 return teamCommand(request,'requestTutorTransport',{appointmentId,quoteId},async({db,tx,tenantId,uid,access})=>{if(!tenantFeature(access.subscription,'transport'))throw new HttpsError('failed-precondition','Transporte ainda não está disponível nesta empresa.',{reason:'PLAN_FEATURE'});
  const ref=db.doc(`tenants/${tenantId}/appointments/${appointmentId}`),appointment=await tx.get(ref);
  if(!appointment.exists||!await tutorOwnsCustomer(tx,db,tenantId,uid,access,appointment.get('customerId')))throw new HttpsError('permission-denied','Agendamento não pertence a esta conta.');
  if(!['REQUESTED','CONFIRMED'].includes(appointment.get('status'))||appointment.get('startsAt').toMillis()<=Date.now())throw new HttpsError('failed-precondition','Este agendamento não aceita mais pedido de transporte.');
  const quoteRef=db.doc(`tenants/${tenantId}/transportQuotes/${quoteId}`),quote=await tx.get(quoteRef),policy=await tx.get(policyRef(db,tenantId));
  if(!quote.exists||quote.get('tutorUid')!==uid||quote.get('appointmentId')||Date.parse(quote.get('expiresAt'))<=Date.now()||!policy.get('enabled')||policy.get('version')!==quote.get('policyVersion'))throw new HttpsError('failed-precondition','Cotação vencida ou alterada. Calcule novamente a taxa.');
  const rows=await appointmentTransportRows(tx,db,tenantId,appointmentId),legs=quote.get('legs');
  const openRequest=doc=>['REQUESTED','CONFIRMED'].includes(doc.get('status'));
  const busy=type=>rows.requests.some(doc=>doc.get('type')===type&&openRequest(doc))||rows.jobs.some(job=>job.get('type')===type&&job.get('status')!=='CANCELLED');
  if(legs.some(leg=>busy(leg.type)))throw new HttpsError('already-exists','Já existe coleta ou retorno em andamento para este agendamento.');
  if(rows.requests.length+legs.length>20)throw new HttpsError('resource-exhausted','Limite de pedidos de transporte deste agendamento atingido.');
  const active=(appointment.get('transport')?.legs??[]).filter(leg=>rows.requests.some(doc=>doc.id===leg.id&&openRequest(doc)));
  const allLegs=[...active,...legs.map(leg=>({id:leg.id,type:leg.type,meters:leg.meters,feeCents:leg.feeCents}))];
  const summary={quoteId,totalCents:allLegs.reduce((total,leg)=>total+leg.feeCents,0),pricing:quote.get('pricing'),legs:allLegs};
  const pets=(appointment.get('items')??[]).map(item=>item.pet),startsAt=appointment.get('startsAt').toDate().toISOString();
  tx.update(quoteRef,{appointmentId});
  for(const leg of legs)tx.create(db.doc(`tenants/${tenantId}/transportRequests/${leg.id}`),{...leg,appointmentId,customerId:appointment.get('customerId'),tutorUid:uid,tenantId,appointmentStartsAt:startsAt,status:'REQUESTED',pets,pricing:quote.get('pricing'),requestedAt:new Date().toISOString(),...metadata(uid,false)});
  tx.update(ref,{transport:summary,...metadata(uid,true)});
  notify(tx,db,tenantId,uid,[{role:'TEAM',type:'TRANSPORT_REQUESTED',title:'Pedido de transporte do tutor',text:`${appointment.get('customer')?.name??'Cliente'} · ${petNames(appointment.get('items'))} · ${noticeDate(appointment.get('localStartsAt'))}`,appointmentId}]);
  return{transport:summary};
 },['TUTOR']);
});
export async function prepareTransportCancellation(tx,db,tenantId,appointmentId){
 const rows=await appointmentTransportRows(tx,db,tenantId,appointmentId);
 if(rows.jobs.some(job=>['PET_COLLECTED','IN_TRANSIT'].includes(job.get('status'))))throw new HttpsError('failed-precondition','Há pets em transporte. Contate a equipe antes de cancelar.');
 const jobs=rows.jobs.filter(job=>['ASSIGNED','GOING_TO_ORIGIN'].includes(job.get('status')));
 const requests=rows.requests.filter(request=>['REQUESTED','CONFIRMED'].includes(request.get('status'))&&!rows.jobs.some(job=>job.id===request.get('transportId')&&job.get('status')==='DELIVERED'));
 return{requests,jobs};
}
export function writeTransportCancellation(tx,prepared,uid){for(const row of prepared.requests)tx.update(row.ref,{status:'CANCELLED',...metadata(uid,true)});for(const job of prepared.jobs)tx.update(job.ref,{status:'CANCELLED',events:[...(job.get('events')??[]),{status:'CANCELLED',actor:uid,createdAt:new Date().toISOString()}],...metadata(uid,true)});}
