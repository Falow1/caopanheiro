import { HttpsError } from 'firebase-functions/v2/https';
import { onCall } from './callable.js';
import { FieldPath } from 'firebase-admin/firestore';
import { actor, identifier, invalid, localBackend, object, options, teamAccess } from './runtime.js';
import { effectiveManagementPermissions } from './management_permissions.js';
import { publicProfessional, requirePrincipal } from './staff_privacy.js';
import { jsonCustomer } from './customers.js';
import { jsonAppointment } from './scheduling.js';
import { professionalRows } from './profiles.js';
import { returnReadiness } from './pet_execution.js';
import { staffMembersFilter } from './staff_members.js';

const resources = {
  MANAGER: ['appointments','customers','services','professionals','blocks','scheduling','members','transports','transportPolicy','transportRequests','tutorLink'],
  ATTENDANT: ['appointments','customers','services','blocks','transports','transportPolicy','transportRequests'],
  PROFESSIONAL: ['appointments'], DRIVER: ['transports'],
};
// Each page has one canonical tenant; no request can mean a global tenant.
export const getCompanyView = onCall(options, async request => {
  const db=localBackend(), uid=await actor(request);
  object(request.data,['tenantId','role','resource','cursor'],'Consulta');
  const tenantId=identifier(request.data.tenantId,'Empresa');
  const {role,resource}=request.data;
  if(typeof role!=='string' || typeof resource!=='string' || !Object.hasOwn(resources,role) || !resources[role].includes(resource)) invalid('Consulta indisponível para esta função.');
  const cursor=request.data.cursor==null?null:identifier(request.data.cursor,'Página');
  return db.runTransaction(async tx=>{
    const access=await teamAccess(tx,db,tenantId,uid,[role]);
    const member=access.member.data();
    if(member.roles.includes('MANAGER') && ['PROFESSIONAL','DRIVER'].includes(role)
      && !effectiveManagementPermissions(member).includes(role==='PROFESSIONAL'?'APPOINTMENTS':'TRANSPORT'))
      throw new HttpsError('permission-denied','Esta função não está disponível neste vínculo.');
    if(resource==='members') requirePrincipal(member);
    if(resource==='tutorLink') {
      // Read only: the fixed link is born when its area opens (getTutorJoinLink),
      // and neither the secret nor the requesters leave here.
      if(cursor) invalid('Esta configuração não possui outra página.');
      if(!effectiveManagementPermissions(member).includes('CUSTOMERS')) throw new HttpsError('permission-denied','Seu acesso não inclui os clientes deste petshop.');
      const link=await tx.get(db.doc('tenants/'+tenantId+'/tutorJoinLinks/current'));
      const principal=member.managementDelegated!==true;
      const pending=principal?await tx.get(db.collection('tenants/'+tenantId+'/tutorJoinRequests').where('status','==','PENDING').limit(51)):null;
      return {tenantId,role,resource,items:[{id:'tutorLink',active:link.exists?link.get('active')===true:null,pendingReturns:pending?Math.min(pending.size,50):null}],nextCursor:null};
    }
    if(['scheduling','transportPolicy'].includes(resource)) {
      if(cursor) invalid('Esta configuração não possui outra página.');
      const doc=await tx.get(db.doc('tenants/'+tenantId+'/settings/'+(resource==='scheduling'?'scheduling':'transport')));
      if(resource==='transportPolicy')return {tenantId,role,resource,items:[{id:'transport',enabled:doc.get('enabled')===true,baseCents:doc.get('baseCents')??null,perKmCents:doc.get('perKmCents')??null}],nextCursor:null};
      return {tenantId,role,resource,items:doc.exists?[{id:doc.id,timeZone:doc.get('timeZone'),days:doc.get('days'),slotMinutes:doc.get('slotMinutes')}]:[],nextCursor:null};
    }
    let query=db.collection('tenants/'+tenantId+'/'+resource);
    if(role==='PROFESSIONAL') query=query.where('professionalUid','==',uid);
    if(role==='DRIVER') query=query.where('driverUid','==',uid);
    // Tutors share the members collection; page only through the team.
    if(resource==='members') query=query.where(staffMembersFilter());
    query=query.orderBy(FieldPath.documentId()).limit(50);
    if(cursor)query=query.startAfter(cursor);
    const page=await tx.get(query);
    let items;
    if(role==='PROFESSIONAL')items=page.docs.flatMap(professionalRows);
    else if(resource==='appointments')items=page.docs.map(jsonAppointment);
    else if(resource==='customers')items=page.docs.map(jsonCustomer);
    else if(resource==='professionals')items=page.docs.map(publicProfessional);
    else if(resource==='members')items=page.docs.filter(doc=>doc.get('roles')?.some(r=>['MANAGER','ATTENDANT','PROFESSIONAL','DRIVER'].includes(r)) || doc.get('staffInvitationPending') || doc.get('activationPending')).map(doc=>({
      id:doc.id,name:doc.get('name')||'Convite pendente',roles:doc.get('roles')??[],invitedRoles:doc.get('invitedRoles')??[],active:doc.get('active')===true,
      principal:doc.get('roles')?.includes('MANAGER')===true&&doc.get('managementDelegated')!==true,
      invitationPending:doc.get('staffInvitationPending')===true||doc.get('activationPending')===true,
    }));
    else if(resource==='services')items=page.docs.map(doc=>({id:doc.id,name:doc.get('name'),description:doc.get('description')??'',durationMinutes:doc.get('durationMinutes'),priceCents:doc.get('priceCents'),active:doc.get('active')===true}));
    else items=page.docs.map(doc=>({id:doc.id,...doc.data(),createdAt:null,updatedAt:null}));
    if(role==='DRIVER') {
      const refs=[...new Set(items.map(job=>job.appointmentId))].map(id=>db.doc('tenants/'+tenantId+'/appointments/'+identifier(id,'Agendamento')));
      const appointments=refs.length?await tx.getAll(...refs):[];
      const byId=new Map(appointments.map(doc=>[doc.id,doc.data()??{}]));
      items=items.map(job=>({...job,pets:returnReadiness(byId.get(job.appointmentId)??{},job.pets??[])}));
    }
    return {tenantId,role,resource,items,nextCursor:page.size===50?page.docs.at(-1).id:null};
  });
});
