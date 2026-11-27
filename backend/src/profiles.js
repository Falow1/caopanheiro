import { hasWorkforceRole, driverEligible } from './workforce_policy.js';
import { executionItems, returnReadiness } from './pet_execution.js';
import { allocateRecordNumbers, petNumberId } from './record_numbers.js';
import { HttpsError } from 'firebase-functions/v2/https';
import { onCall } from './callable.js';
import { getAuth } from 'firebase-admin/auth';
import { FieldPath } from 'firebase-admin/firestore';
import { actor, email, identifier, invalid, localBackend, object, options, teamAccess, text, tenantEnabled } from './runtime.js';
import { brazilPhone } from './contact_policy.js';
import { metadata, teamCommand } from './team_commands.js';
import { jsonCustomer } from './customers.js';
import { keepLegacyBreed, normalizedPet, petBlocksRef, petInput, petPolicyRef, petServiceContext, publicPetPolicy, refuseUnservedPet, servedCustomer, storedPetPolicy } from './pet_policy.js';
import { recordBreedSuggestion } from './pet_service.js';
import { jsonAppointment, tutorView } from './scheduling.js';
import { tutorOwnsCustomer } from './tutor_access.js';
import { BILLING_BLOCKED, BILLING_GRACE, BOOKINGS_PAUSED, companySuspended, tutorReadOnly } from './access_policy.js';
import { tenantPhase } from './billing_phase.js';
import { pendingManager } from './manager_activation.js';
import { screenTips } from './screen_tips.js';

const profileRoles=['TUTOR','PROFESSIONAL','DRIVER'];
const roleValue=(value)=>{if(!profileRoles.includes(value))invalid('Aplicativo inválido.');return value;};
export const getApplicationContext=onCall(options,async(request)=>{
  const db=localBackend();const uid=await actor(request);object(request.data,['role'],'Consulta');const role=roleValue(request.data.role);
  const links=await db.collection(`users/${uid}/tenantLinks`).limit(51).get();if(links.size>50)throw new HttpsError('failed-precondition','Quantidade de vínculos requer revisão administrativa.');
  const user=await getAuth().getUser(uid);const ownProfile=await db.doc('users/'+uid).get();const companies=[],unavailableCompanies=[];
  // A principal manager account is deleted only by the SaaS: the apps hide their own deletion.
  let principalManager=!(await db.collection('tenants').where('principalManagerUid','==',uid).limit(1).get()).empty;
  for(const link of links.docs){
    const id=identifier(link.id,'Empresa');const [tenant,member,subscription]=await db.getAll(db.doc(`tenants/${id}`),db.doc(`tenants/${id}/members/${uid}`),db.doc(`subscriptions/${id}`));
    if(member.get('roles')?.includes('MANAGER')&&member.get('managementDelegated')!==true||pendingManager(member.data()))principalManager=true;
    if(!member.exists||member.get('active')!==true||!(member.get('roles')?.includes(role) || hasWorkforceRole(member.get('roles'),role)))continue;
    // Suspended company or invalid subscription: the link still exists, so the
    // app can explain the pause instead of reporting a removed link.
    // A petshop without the tutor app stays listed for reading only (A1-u).
    // Expired plan (E2) and platform suspension: the tutor keeps reading the
    // petshop, with its phone, and never learns that the reason is payment.
    const enabled=tenantEnabled(tenant,subscription);
    const phase=enabled?await tenantPhase(db,db,tenant,subscription):null;
    const suspended=tenant.exists&&companySuspended(tenant.data())&&subscription.get('tenantId')===tenant.id;
    const readOnly=role==='TUTOR'&&(tutorReadOnly(tenant,subscription)||suspended||phase?.phase===BILLING_BLOCKED);
    if(!readOnly&&(!enabled||phase?.phase===BILLING_BLOCKED)){if(tenant.exists)unavailableCompanies.push({id,name:tenant.get('tradeName')??id});continue;}
    const bookingState=role!=='TUTOR'||readOnly?{}:phase?.phase===BOOKINGS_PAUSED?{bookingPaused:true,contactPhone:tenant.get('phone')??''}
      :phase?.phase===BILLING_GRACE?{bookingNotice:{from:phase.deadlineAt}}:{};
    if(role==='DRIVER'&&!driverEligible(member.data()))continue;
    let profile;
    if(role==='TUTOR'){
      const customerId=member.get('customerId');if(!customerId)continue;
      const customer=await db.doc(`tenants/${id}/customers/${identifier(customerId,'Cliente')}`).get();if(!customer.exists||customer.get('tutorUid')!==uid)continue;
      profile={id:uid,customerId,recordNumber:customer.get('recordNumber')??null,name:customer.get('name'),phone:customer.get('phone'),email:user.email??customer.get('email')};
    }else if(role==='PROFESSIONAL'){
      const professionalId=member.get('professionalId');if(!professionalId){if(member.get('roles')?.includes('MANAGER')){companies.push({id,name:tenant.get('tradeName')??id,profile:{id:uid,name:member.get('name')??user.displayName??'Gestor',role:'Gestor',email:user.email??'',phone:member.get('phone')??''}});}continue;}
      const professional=await db.doc(`tenants/${id}/professionals/${identifier(professionalId,'Profissional')}`).get();
      if(!professional.exists||professional.get('active')!==true||professional.get('authUid')!==uid)continue;
      profile={id:professional.id,recordNumber:professional.get('recordNumber')??null,name:professional.get('name'),role:professional.get('specialty'),email:user.email??'',phone:member.get('phone')??user.phoneNumber??''};
    }else{profile={id:uid,recordNumber:member.get('recordNumber')??null,name:member.get('name')??user.displayName??'Entregador',email:user.email??'',phone:member.get('phone')??user.phoneNumber??''};}
    companies.push({id,recordNumber:tenant.get('recordNumber')??null,name:tenant.get('tradeName')??id,profile,...(readOnly?{readOnly:true,contactPhone:tenant.get('phone')??''}:bookingState)});
  }
  if(!companies.length&&role!=='TUTOR'){
    if(unavailableCompanies.length)throw new HttpsError('permission-denied','O acesso da sua empresa está indisponível no momento. Fale com o gestor do petshop.',{reason:'COMPANY_UNAVAILABLE'});
    throw new HttpsError('permission-denied','Sua conta não possui vínculo ativo neste aplicativo.');
  }
  companies.sort((a,b)=>a.name.localeCompare(b.name,'pt-BR'));unavailableCompanies.sort((a,b)=>a.name.localeCompare(b.name,'pt-BR'));
  return {uid,profile:{id:uid,name:ownProfile.get('name')??user.displayName??'',email:user.email??'',phone:ownProfile.get('phone')??user.phoneNumber??''},companies,unavailableCompanies,principalManager,screenTips:screenTips(ownProfile)};
});

/// Tutor view: professional observations travel without the author's UID,
/// and team notes and team account identifiers do not travel at all.
export function tutorAppointment(doc){
  const value=tutorView(jsonAppointment(doc));
  return{...value,observations:value.observations??[]};
}
export function professionalRows(doc){
  const value=jsonAppointment(doc);
  return value.items.map((item)=>({id:`${doc.id.length}:${doc.id}${item.pet.id}`,appointmentId:doc.id,recordNumber:value.recordNumber??null,startsAt:value.startsAt,localStartsAt:value.localStartsAt??null,
    status:item.execution.status,execution:item.execution,appointmentStatus:value.status,notes:value.notes??'',tutorNotes:value.tutorNotes??'',tutorName:value.customer.name,pet:item.pet,services:item.services,
    observations:(value.observations??[]).filter((observation)=>observation.petId===item.pet.id).map(({text,createdAt})=>({text,createdAt}))}));
}

export const getProfileData=onCall(options,async(request)=>{
  const db=localBackend();const uid=await actor(request);object(request.data,['tenantId','role','resource','cursor'],'Consulta');
  const tenantId=identifier(request.data.tenantId,'Empresa');const role=roleValue(request.data.role);const resource=request.data.resource;
  const allowed={TUTOR:['customer','services','appointments'],PROFESSIONAL:['appointments'],DRIVER:['transports']};if(!allowed[role].includes(resource))invalid('Consulta não permitida para este aplicativo.');
  const cursor=request.data.cursor==null?null:identifier(request.data.cursor,'Página');
  return db.runTransaction(async(tx)=>{
    const access=await teamAccess(tx,db,tenantId,uid,[role],{tutorRead:role==='TUTOR'});
    if(role==='DRIVER'&&!driverEligible(access.member.data()))throw new HttpsError('permission-denied','Esta função não está disponível neste vínculo.');
    if(resource==='customer'){
      const customerId=identifier(access.member.get('customerId'),'Cliente');const customer=await tx.get(db.doc(`tenants/${tenantId}/customers/${customerId}`));
      if(!customer.exists||customer.get('tutorUid')!==uid)throw new HttpsError('permission-denied','Cadastro não vinculado a esta conta.');
      // Each pet says whether the petshop serves it; a block reaches the tutor
      // without its internal reason, with the petshop phone.
      const context=await petServiceContext(tx,db,tenantId,[customerId]);
      return{items:[servedCustomer(jsonCustomer(customer),context,{team:false,contactPhone:access.tenant.get('phone')??''})],petPolicy:publicPetPolicy(context.policy),nextCursor:null};
    }
    const collection=resource==='services'?'services':resource;
    let query=db.collection(`tenants/${tenantId}/${collection}`);
    // The customer record is the anchor: appointments booked by the team before
    // the tutor linked the account belong to the same record and must appear.
    let tutorCustomerId=null;
    if(role==='TUTOR'&&resource==='appointments'){
      tutorCustomerId=access.member.get('customerId');
      if(!await tutorOwnsCustomer(tx,db,tenantId,uid,access,tutorCustomerId))throw new HttpsError('permission-denied','Cadastro não vinculado a esta conta.');
      query=query.where('customerId','==',tutorCustomerId);
    }
    if(role==='PROFESSIONAL')query=query.where('professionalUid','==',uid);
    if(role==='DRIVER')query=query.where('driverUid','==',uid);
    if(resource==='services')query=query.where('active','==',true);
    query=query.orderBy(FieldPath.documentId()).limit(50);if(cursor)query=query.startAfter(cursor);
    const page=await tx.get(query);let items;
    if(role==='PROFESSIONAL')items=page.docs.flatMap(professionalRows);
    else if(role==='TUTOR'&&resource==='appointments')items=page.docs.filter((doc)=>doc.get('customerId')===tutorCustomerId).map(tutorAppointment);
    else items=page.docs.map((doc)=>({id:doc.id,...doc.data(),createdAt:null,updatedAt:null}));
    if(role==='DRIVER'){const refs=[...new Set(items.map(job=>job.appointmentId))].map(id=>db.doc(`tenants/${tenantId}/appointments/${id}`));const appointments=refs.length?await tx.getAll(...refs):[];const byId=new Map(appointments.map(doc=>[doc.id,doc.data()??{}]));items=items.map(job=>({...job,pets:returnReadiness(byId.get(job.appointmentId)??{},job.pets??[])}));}
    return{items,nextCursor:page.size===50?page.docs.at(-1).id:null};
  });
});

export const addServiceObservation=onCall(options,async(request)=>{
  object(request.data,['tenantId','requestId','appointmentId','petId','text'],'Pedido');
  const appointmentId=identifier(request.data.appointmentId,'Agendamento');const petId=identifier(request.data.petId,'Pet');const value=text(request.data.text,'Observação',2000,1);
  return teamCommand(request,'addServiceObservation',{appointmentId,petId,text:value},async({db,tx,tenantId,uid})=>{
    const ref=db.doc(`tenants/${tenantId}/appointments/${appointmentId}`);const previous=await tx.get(ref);
    if(!previous.exists||previous.get('professionalUid')!==uid)throw new HttpsError('permission-denied','Atendimento não atribuído a você.');
    if(!executionItems(previous.data()).some(item=>item.pet.id===petId&&['PET_RECEIVED','IN_PROGRESS'].includes(item.execution.status)))throw new HttpsError('failed-precondition','Observação indisponível para este atendimento.');
    const observations=previous.get('observations')??[];if(observations.length>=100)invalid('Limite de observações do atendimento atingido.');
    const updated=[...observations,{petId,text:value,createdAt:new Date().toISOString(),authorUid:uid}];tx.update(ref,{observations:updated,...metadata(uid,true)});
    return{appointment:{...jsonAppointment(previous),observations:updated}};
  },['PROFESSIONAL']);
});

export const updateTutorProfile=onCall(options,async(request)=>{
  object(request.data,['tenantId','requestId','name','phone','email'],'Pedido');
  const name=text(request.data.name,'Nome',100,2);const phone=brazilPhone(text(request.data.phone,'Telefone',32,8));const contact=email(request.data.email);
  const db=localBackend();const uid=await actor(request);const user=await getAuth().getUser(uid);
  if(!user.emailVerified||contact!==user.email?.toLowerCase())throw new HttpsError('failed-precondition','O contato deve corresponder ao e-mail verificado da conta.');
  return teamCommand(request,'updateTutorProfile',{name,phone,email:contact},async({db,tx,tenantId,uid,access})=>{
    const customerId=identifier(access.member.get('customerId'),'Cliente');const ref=db.doc(`tenants/${tenantId}/customers/${customerId}`);const previous=await tx.get(ref);
    if(!previous.exists||previous.get('tutorUid')!==uid)throw new HttpsError('permission-denied','Cadastro não vinculado.');
    tx.update(ref,{name,phone,email:contact,...metadata(uid,true)});return{tutor:{name,phone,email:contact,recordNumber:previous.get('recordNumber')??null}};
  },['TUTOR']);
});

/// Each person of the team edits their own name and phone, never the e-mail
/// of the login. The change reaches every company where they work.
export const updateOwnTeamProfile=onCall(options,async(request)=>{
  object(request.data,['name','phone'],'Pedido');
  const name=text(request.data.name,'Nome',100,2);const phone=brazilPhone(text(request.data.phone,'Telefone',32,8));
  const db=localBackend();const uid=await actor(request);
  const links=await db.collection(`users/${uid}/tenantLinks`).limit(51).get();if(links.size>50)throw new HttpsError('failed-precondition','Quantidade de vínculos requer revisão administrativa.');
  await db.runTransaction(async(tx)=>{
    const refs=links.docs.map((link)=>db.doc(`tenants/${identifier(link.id,'Empresa')}/members/${uid}`));
    const members=(refs.length?await tx.getAll(...refs):[]).filter((doc)=>doc.exists&&doc.get('active')===true&&(doc.get('roles')??[]).some((role)=>role!=='TUTOR'));
    if(!members.length)throw new HttpsError('permission-denied','Sua conta não possui vínculo ativo de equipe.');
    const professionalRefs=members.filter((doc)=>typeof doc.get('professionalId')==='string').map((doc)=>db.doc(`${doc.ref.parent.parent.path}/professionals/${identifier(doc.get('professionalId'),'Profissional')}`));
    const professionals=professionalRefs.length?await tx.getAll(...professionalRefs):[];
    tx.set(db.doc(`users/${uid}`),{name,phone},{merge:true});
    for(const doc of members)tx.update(doc.ref,{name,phone,...metadata(uid,true)});
    for(const doc of professionals)if(doc.exists&&doc.get('authUid')===uid)tx.update(doc.ref,{name,...metadata(uid,true)});
  });
  return{profile:{name,phone}};
});

export const saveTutorPet=onCall(options,async(request)=>{
  object(request.data,['tenantId','requestId','petId','pet'],'Pedido');const petId=identifier(request.data.petId,'Pet');
  const{pet:input,suggestion}=petInput(request.data.pet,petId);
  return teamCommand(request,'saveTutorPet',{pet:input,suggestion},async({db,tx,tenantId,uid,access})=>{
    const customerId=identifier(access.member.get('customerId'),'Cliente');const ref=db.doc(`tenants/${tenantId}/customers/${customerId}`);
    const[previous,policyDoc,blocks]=await tx.getAll(ref,petPolicyRef(db,tenantId),petBlocksRef(db,tenantId,customerId));
    if(!previous.exists||previous.get('tutorUid')!==uid)throw new HttpsError('permission-denied','Cadastro não vinculado.');
    const pets=previous.get('pets')??{};if(!pets[petId]&&Object.keys(pets).length>=100)invalid('Limite de pets atingido.');
    const before=pets[petId]?normalizedPet(pets[petId]):null;const pet=keepLegacyBreed({...input},before);const policy=storedPetPolicy(policyDoc);
    // Only a breed the petshop serves can be added or chosen; the tutor reads the rule, never a block reason.
    if(!before||before.breedCode!==pet.breedCode)refuseUnservedPet(policy,pet,{tutor:true,petshop:access.tenant.get('tradeName')??'O petshop'});
    [pet.recordNumber]=await allocateRecordNumbers(tx,db,tenantId,[{type:'pets',id:petNumberId(customerId,petId),recordNumber:pets[petId]?.recordNumber}]);
    tx.update(ref,{[`pets.${petId}`]:pet,...metadata(uid,true)});
    if(suggestion)recordBreedSuggestion(tx,db,pet.species,suggestion);
    const[served]=servedCustomer({id:customerId,pets:[pet]},{policy,blocks:new Map([[customerId,blocks.get('pets')??{}]])},{team:false,contactPhone:access.tenant.get('phone')??''}).pets;
    return{pet:served};
  },['TUTOR']);
});
