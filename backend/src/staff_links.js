import { prepareTenantLinks } from './tenant_links.js';
import { parseManagementPermissions, managementPermissions as allManagementPermissions } from './management_permissions.js';
import { INVITATION_TTL_MS, invitationDeadline, staffIssuedAt } from './invitation_policy.js';
import { HttpsError } from 'firebase-functions/v2/https';
import { onCall } from './callable.js';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { actor, localBackend, object, options, identifier, text, email, digest, teamAccess, tenantEnabled, tenantOpen, accountAvailable } from './runtime.js';
import { brazilPhone } from './contact_policy.js';
import { teamCommand, metadata } from './team_commands.js';
import { operationalRoles } from './workforce_policy.js';
import { pendingStaff } from './staff_invitation_policy.js';
import { staffSeatOccupied } from './manager_activation.js';
import { staffMembers } from './staff_members.js';
import { checkPassword } from './password_check.js';
import { requirePrincipal } from './staff_privacy.js';
import { allocateRecordNumbers, prepareRecordNumbers } from './record_numbers.js';
import { prepareProfessionalAppointments, writeProfessionalAppointments } from './professional_binding.js';
import { reserveAttempt, clearSuccessfulEmail, loginPolicy, lookupPolicy } from './team_login_policy.js';
const source = request => request.rawRequest.ip || request.rawRequest.socket?.remoteAddress || 'unknown';
function secret(value) { if(typeof value!=='string'||!/^[a-f0-9]{32,64}$/.test(value))throw new HttpsError('invalid-argument','Link de convite inválido.'); return value; }
function linkInput(data, allowed) { object(data,allowed,'Convite');return{tenantId:identifier(data.tenantId,'Petshop'),inviteId:identifier(data.inviteId,'Convite'),tokenHash:digest(secret(data.token))}; }
function validLink(member, tokenHash) { return member?.linkInvitation===true && member.invitationTokenHash===tokenHash; }
async function linkState(reader,db,tenantId,inviteId,tokenHash,{allowUsed=false}={}) {
  const refs=[db.doc('tenants/'+tenantId),db.doc('tenants/'+tenantId+'/members/'+inviteId),db.doc('subscriptions/'+tenantId)];
  const [tenant,invite,subscription]=await reader.getAll(...refs);
  if(!(await tenantOpen(reader,db,tenant,subscription))||!validLink(invite.data(),tokenHash)||!pendingStaff(invite.data())&&!(allowUsed&&invite.get('invitationUsedBy')))
    throw new HttpsError('failed-precondition','Convite inválido, expirado ou já utilizado. Solicite outro ao gestor.');
  return{tenant,invite};
}
async function capacity(tx,db,tenant,excludeIds=[]) {
  const members=await staffMembers(tx,db,tenant.id);
  const plan=await tx.get(db.doc('plans/'+identifier(tenant.get('planId'),'Plano')));
  if(!plan.exists||plan.get('active')!==true||!Number.isSafeInteger(plan.get('maxUsers'))||members.docs.filter(doc=>!excludeIds.includes(doc.id)&&staffSeatOccupied(doc.data())).length>=plan.get('maxUsers'))
    throw new HttpsError('failed-precondition','Limite de usuários do plano atingido.');
  return{members,plan};
}
export const createStaffLink = onCall(options, async request=>{
  object(request.data,['tenantId','requestId','token','kind','roles','professionalId','managementPermissions','tenantIds'],'Convite');
  const tokenHash=digest(secret(request.data.token)),kind=request.data.kind;
  if(!['MANAGEMENT','OPERATIONAL'].includes(kind))throw new HttpsError('invalid-argument','Escolha o tipo de acesso.');
  const roles=kind==='MANAGEMENT'?['MANAGER']:request.data.roles;
  if(!Array.isArray(roles)||!roles.length||new Set(roles).size!==roles.length||kind==='OPERATIONAL'&&roles.some(r=>!operationalRoles.includes(r)))throw new HttpsError('invalid-argument','Escolha funções operacionais válidas.');
  if(kind==='MANAGEMENT'&&request.data.roles!=null&&JSON.stringify(request.data.roles)!=='["MANAGER"]')throw new HttpsError('invalid-argument','Funções inválidas para gestão.');
  if(kind==='OPERATIONAL' && request.data.managementPermissions!=null)throw new HttpsError('invalid-argument','Permissões de gestão não se aplicam ao funcionário.');
  const managementPermissions=kind==='MANAGEMENT'?parseManagementPermissions(request.data.managementPermissions??allManagementPermissions):null;
  const professionalId=request.data.professionalId==null?null:identifier(request.data.professionalId,'Profissional');
  if(professionalId&&!roles.includes('PROFESSIONAL'))throw new HttpsError('invalid-argument','O cadastro exige função profissional.');
  const anchor=identifier(request.data.tenantId,'Petshop');
  const tenantIds=request.data.tenantIds??[anchor];
  if(!Array.isArray(tenantIds)||!tenantIds.length||tenantIds.length>50||new Set(tenantIds).size!==tenantIds.length||!tenantIds.includes(anchor)||kind==='OPERATIONAL'&&tenantIds.length!==1)throw new HttpsError('invalid-argument','Selecione empresas válidas para o convite. Funcionários recebem um convite por empresa.');
  tenantIds.forEach(id=>identifier(id,'Petshop'));tenantIds.sort();
  const authorizeCompanies=async({tx,db,uid})=>{for(const id of tenantIds)requirePrincipal((await teamAccess(tx,db,id,uid,['MANAGER'])).member.data());};
  const normalized={kind,roles,professionalId,tokenHash,...(request.data.managementPermissions!=null?{managementPermissions}:{}),...(request.data.tenantIds!=null?{tenantIds}:{})};
  return teamCommand(request,'createStaffLink',normalized,async({db,tx,tenantId,uid,access})=>{
    await authorizeCompanies({tx,db,uid});
    const inviteId='invite-'+identifier(request.data.requestId,'Operação',16),prepared=[];
    for(const id of tenantIds) {
      const tenant=id===tenantId?access.tenant:await tx.get(db.doc('tenants/'+id));
      await capacity(tx,db,tenant);
      if(professionalId){const pro=await tx.get(db.doc('tenants/'+id+'/professionals/'+professionalId));if(!pro.exists||pro.get('authUid'))throw new HttpsError('failed-precondition','Cadastro indisponível para novo vínculo.');}
      const ref=db.doc('tenants/'+id+'/members/'+inviteId),previous=await tx.get(ref);
      if(previous.exists)throw new HttpsError('already-exists','Convite já existe.');
      prepared.push({id,ref});
    }
    const issuedAt=Timestamp.now(),expiresAt=Timestamp.fromMillis(issuedAt.toMillis()+INVITATION_TTL_MS);
    for(const {id,ref} of prepared) {
      tx.create(ref,{name:'Convite pendente',roles:[],active:false,staffInvitationPending:true,linkInvitation:true,invitationKind:kind,invitedRoles:roles,invitedManagementPermissions:managementPermissions,
        invitationTenantIds:tenantIds,invitationAnchorTenantId:tenantId,invitedProfessionalId:professionalId,invitationTokenHash:tokenHash,staffInvitationIssuedAt:issuedAt,staffInvitationExpiresAt:expiresAt,...metadata(uid,false)});
      tx.create(db.collection('tenants/'+id+'/workforceEvents').doc(),{action:'LINK_CREATED',actorUid:uid,inviteId,kind,roles,createdAt:FieldValue.serverTimestamp()});
    }
    return{inviteId,expiresAt:expiresAt.toMillis(),kind};
  },['MANAGER'],authorizeCompanies);
});
export const inspectStaffLink = onCall(options, async request=>{
  const {tenantId,inviteId,tokenHash}=linkInput(request.data,['tenantId','inviteId','token']);
  const db=localBackend();await reserveAttempt(db,'staffLinkLookup',tenantId+':'+inviteId,source(request),lookupPolicy);
  const {tenant,invite}=await linkState(db,db,tenantId,inviteId,tokenHash);
  const companies=[];
  for(const id of invite.get('invitationTenantIds')??[tenantId]) {const state=await linkState(db,db,id,inviteId,tokenHash);companies.push({id,name:state.tenant.get('tradeName')??state.tenant.get('name')});}
  return{companies,managementPermissions:invite.get('invitedManagementPermissions')??null,tenantId,companyName:tenant.get('tradeName')??tenant.get('name'),kind:invite.get('invitationKind'),roles:invite.get('invitedRoles'),expiresAt:invitationDeadline(invite.get('staffInvitationExpiresAt'),staffIssuedAt(invite.data()))};
});
export const loginStaffLink = onCall(options, async request=>{
  const {tenantId,inviteId,tokenHash}=linkInput(request.data,['tenantId','inviteId','token','email','password']);
  const contact=email(request.data.email),password=request.data.password;
  if(typeof password!=='string'||password.length<1||password.length>4096)throw new HttpsError('unauthenticated','E-mail ou senha incorretos.');
  const db=localBackend();await linkState(db,db,tenantId,inviteId,tokenHash);
  const attempt=await reserveAttempt(db,'login',contact,source(request),loginPolicy);
  let response;try{response=await checkPassword(contact,password);}catch{throw new HttpsError('unavailable','Não foi possível confirmar o acesso.');}
  if(!response.ok)throw new HttpsError('unauthenticated','E-mail ou senha incorretos.',{reason:'LOGIN_DENIED',retryAfterMs:attempt.retryAfterMs});
  const result=await response.json();await linkState(db,db,tenantId,inviteId,tokenHash);
  const account=await getAuth().getUser(result.localId);
  if(account.disabled||account.email?.toLowerCase()!==contact)throw new HttpsError('unauthenticated','E-mail ou senha incorretos.');
  const token=await getAuth().createCustomToken(account.uid);await clearSuccessfulEmail(db,attempt);return{customToken:token};
});
export const acceptStaffLink = onCall(options, async request=>{
  const {tenantId,inviteId,tokenHash}=linkInput(request.data,['tenantId','inviteId','token','name','phone','specialty']);
  const name=text(request.data.name,'Nome',100,2),phone=brazilPhone(text(request.data.phone,'Telefone',32,8));
  const db=localBackend(),uid=await actor(request),account=await getAuth().getUser(uid);
  if(!account.emailVerified||account.disabled)throw new HttpsError('failed-precondition','Confirme seu e-mail antes de concluir o cadastro.');
  return db.runTransaction(async tx=>{
    const initial=await tx.get(db.doc('tenants/'+tenantId+'/members/'+inviteId));
    if((initial.get('invitationTenantIds')??[]).length>1)return acceptManagementGroup(tx,db,uid,account,{tenantId,inviteId,tokenHash,name,phone},initial);
    await accountAvailable(tx,db,uid);
    const {tenant,invite}=await linkState(tx,db,tenantId,inviteId,tokenHash,{allowUsed:true});
    const memberRef=db.doc('tenants/'+tenantId+'/members/'+uid),member=await tx.get(memberRef);
    if(invite.get('invitationUsedBy')) {
      if(invite.get('invitationUsedBy')===uid&&member.get('active')===true&&member.get('acceptedInvitationId')===inviteId&&!member.get('unlinkedAt'))return{completed:true,tenantId};
      throw new HttpsError('failed-precondition','Convite já utilizado.');
    }
    if(member.get('activationPending')||member.get('roles')?.includes('MANAGER')&&member.get('managementDelegated')!==true||member.get('active')&&member.get('roles')?.some(r=>['MANAGER',...operationalRoles].includes(r)))
      throw new HttpsError('failed-precondition','A pessoa já possui acesso ou depende da administração do SaaS.');
    const {plan}=await capacity(tx,db,tenant,[inviteId,uid]);
    const roles=invite.get('invitedRoles'),management=invite.get('invitationKind')==='MANAGEMENT';
    let professional=null,professionalId=null,unassigned=[];
    if(roles.includes('PROFESSIONAL')) {
      professionalId=invite.get('invitedProfessionalId');
      if(!professionalId){const former=await tx.get(db.collection('tenants/'+tenantId+'/professionals').where('formerAuthUid','==',uid).limit(2));if(former.size>1)throw new HttpsError('failed-precondition','Solicite convite vinculado ao seu cadastro profissional anterior.');professionalId=former.docs[0]?.id??('pro-'+digest(uid).slice(0,32));}
      professional=await tx.get(db.doc('tenants/'+tenantId+'/professionals/'+identifier(professionalId,'Profissional')));
      if(professional.get('authUid')&&professional.get('authUid')!==uid||professional.get('formerAuthUid')&&professional.get('formerAuthUid')!==uid)throw new HttpsError('failed-precondition','Este cadastro pertence a outra pessoa. Solicite um novo convite.');
      const all=await tx.get(db.collection('tenants/'+tenantId+'/professionals').where('active','==',true).limit(101));
      if(professional.get('active')!==true&&all.size>=plan.get('maxProfessionals'))throw new HttpsError('failed-precondition','Limite de profissionais do plano atingido.');
      unassigned=await prepareProfessionalAppointments(tx,db,tenantId,professionalId);
    }
    const nextRoles=[...new Set([...(member.get('roles')??[]).filter(r=>!['MANAGER',...operationalRoles].includes(r)),...roles])];
    const allocations=[{type:'members',id:uid,recordNumber:member.get('recordNumber')},...(professional?[{type:'professionals',id:professionalId,recordNumber:professional.get('recordNumber')}]:[])];
    const writeLinks=await prepareTenantLinks(tx,db,uid,[tenantId]);
    const numbers=await allocateRecordNumbers(tx,db,tenantId,allocations);
    writeLinks();
    const specialty=roles.includes('PROFESSIONAL')?text(request.data.specialty??professional.get('specialty')??'Profissional','Especialidade',100,1):null;
    tx.set(memberRef,{recordNumber:numbers[0],name,phone,email:account.email.toLowerCase(),roles:nextRoles,active:true,managementDelegated:management,
      managementPermissions:management?parseManagementPermissions(invite.get('invitedManagementPermissions')??allManagementPermissions):FieldValue.delete(),
      professionalId:professionalId??FieldValue.delete(),unlinkedAt:FieldValue.delete(),staffInvitationPending:false,acceptedInvitationId:inviteId,...metadata(uid,member.exists)},{merge:true});
    if(professional){tx.set(professional.ref,{recordNumber:numbers[1],name,specialty,active:true,authUid:uid,formerAuthUid:FieldValue.delete(),...metadata(uid,professional.exists)},{merge:true});writeProfessionalAppointments(tx,unassigned,uid,uid);}
    tx.set(db.doc('users/'+uid),{name,phone,updatedAt:FieldValue.serverTimestamp()},{merge:true});
    tx.set(db.doc('users/'+uid+'/tenantLinks/'+tenantId),{});
    tx.update(invite.ref,{staffInvitationPending:false,invitationUsedBy:uid,invitationUsedAt:FieldValue.serverTimestamp(),...metadata(uid,true)});
    tx.create(db.collection('tenants/'+tenantId+'/workforceEvents').doc(),{action:'LINK_ACCEPTED',actorUid:uid,inviteId,roles,createdAt:FieldValue.serverTimestamp()});
    return{completed:true,tenantId};
  });
});

async function acceptManagementGroup(tx,db,uid,account,{tenantId,inviteId,tokenHash,name,phone},initial) {
  await accountAvailable(tx,db,uid);
  const ids=initial.get('invitationTenantIds');
  if(initial.get('invitationKind')!=='MANAGEMENT'||!Array.isArray(ids)||!ids.includes(tenantId)||ids.length>50)throw new HttpsError('failed-precondition','Convite inválido.');
  const writeLinks=await prepareTenantLinks(tx,db,uid,ids);
  const prepared=[];
  for(const id of ids) {
    identifier(id,'Petshop');
    const {tenant,invite}=await linkState(tx,db,id,inviteId,tokenHash,{allowUsed:true});
    if(invite.get('invitationKind')!=='MANAGEMENT'||JSON.stringify(invite.get('invitationTenantIds'))!==JSON.stringify(ids)||invite.get('createdBy')!==initial.get('createdBy'))throw new HttpsError('failed-precondition','Convite inconsistente.');
    const memberRef=db.doc('tenants/'+id+'/members/'+uid),member=await tx.get(memberRef);
    if(invite.get('invitationUsedBy')) {
      if(invite.get('invitationUsedBy')===uid&&member.get('active')===true&&member.get('acceptedInvitationId')===inviteId&&!member.get('unlinkedAt')){prepared.push({id,replayed:true});continue;}
      throw new HttpsError('failed-precondition','Convite já utilizado.');
    }
    requirePrincipal((await teamAccess(tx,db,id,invite.get('createdBy'),['MANAGER'])).member.data());
    if(member.get('roles')?.includes('MANAGER')&&member.get('managementDelegated')!==true||member.get('activationPending')||member.get('active')===true&&member.get('roles')?.some(r=>['MANAGER',...operationalRoles].includes(r)))throw new HttpsError('failed-precondition','A pessoa já possui acesso em uma empresa selecionada.');
    await capacity(tx,db,tenant,[inviteId,uid]);
    const permissions=parseManagementPermissions(invite.get('invitedManagementPermissions')??allManagementPermissions);
    const allocation=await prepareRecordNumbers(tx,db,id,[{type:'members',id:uid,recordNumber:member.get('recordNumber')}]);
    prepared.push({id,invite,member,memberRef,permissions,allocation});
  }
  if(prepared.some(p=>p.replayed)&&!prepared.every(p=>p.replayed))throw new HttpsError('failed-precondition','Convite parcialmente consumido; solicite revisão.');
  if(prepared.every(p=>p.replayed))return{completed:true,tenantId,tenantIds:ids};
  writeLinks();
  for(const {id,invite,member,memberRef,permissions,allocation} of prepared) {
    allocation.write();
    tx.set(memberRef,{recordNumber:allocation.numbers[0],name,phone,email:account.email.toLowerCase(),roles:[...new Set([...(member.get('roles')??[]).filter(r=>!['MANAGER',...operationalRoles].includes(r)),'MANAGER'])],active:true,managementDelegated:true,managementPermissions:permissions,unlinkedAt:FieldValue.delete(),staffInvitationPending:false,acceptedInvitationId:inviteId,...metadata(uid,member.exists)},{merge:true});
    tx.set(db.doc('users/'+uid+'/tenantLinks/'+id),{});
    tx.update(invite.ref,{staffInvitationPending:false,invitationUsedBy:uid,invitationUsedAt:FieldValue.serverTimestamp(),...metadata(uid,true)});
    tx.create(db.collection('tenants/'+id+'/workforceEvents').doc(),{action:'LINK_ACCEPTED',actorUid:uid,inviteId,roles:['MANAGER'],createdAt:FieldValue.serverTimestamp()});
  }
  tx.set(db.doc('users/'+uid),{name,phone,updatedAt:FieldValue.serverTimestamp()},{merge:true});
  return{completed:true,tenantId,tenantIds:ids};
}
