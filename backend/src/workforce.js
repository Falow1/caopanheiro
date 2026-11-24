import { transferWorkforce } from './workforce_transfer.js';
import { parseManagementPermissions, effectiveManagementPermissions } from './management_permissions.js';
import { prepareProfessionalAppointments, writeProfessionalAppointments } from './professional_binding.js';
import { HttpsError } from 'firebase-functions/v2/https';
import { onCall } from './callable.js';
import { FieldValue } from 'firebase-admin/firestore';
import { actor, localBackend, object, options, identifier, teamAccess } from './runtime.js';
import { teamCommand, metadata } from './team_commands.js';
import { requireEditableWorkforceMember, requireNoOpenAssignments } from './workforce_access.js';
import { operationalRoles } from './workforce_policy.js';
import { pendingStaff } from './staff_invitation_policy.js';
import { requirePrincipal } from './staff_privacy.js';
import { tenantAudit } from './tenant_audit.js';
import { staffMembers } from './staff_members.js';

export const getWorkforceMembers = onCall(options, async request => {
  object(request.data,['tenantId'],'Consulta');
  const db=localBackend(), uid=await actor(request), tenantId=identifier(request.data.tenantId,'Petshop');
  return db.runTransaction(async tx=>{
    const access=await teamAccess(tx,db,tenantId,uid,['MANAGER']); requirePrincipal(access.member.data());
    const rows=await staffMembers(tx,db,tenantId);
    return {members:rows.docs.filter(doc=>doc.get('staffInvitationPending')===true || doc.get('activationPending')===true || doc.get('roles')?.some(r=>['MANAGER',...operationalRoles].includes(r))).map(doc=>({
      id:doc.id, name:doc.get('name') || (doc.get('staffInvitationPending')?'Convite pendente':'Integrante da equipe'),
      roles:(doc.get('roles')??[]).filter(r=>['MANAGER',...operationalRoles].includes(r)), active:doc.get('active')===true,
      professionalId:doc.get('professionalId')??null, activationPending:doc.get('activationPending')===true,
      invitationPending:doc.get('staffInvitationPending')===true, invitationExpired:doc.get('staffInvitationPending')===true&&!pendingStaff(doc.data()),
      invitedRoles:doc.get('invitedRoles')??[], invitedProfessionalId:doc.get('invitedProfessionalId')??null,
      managementDelegated:doc.get('managementDelegated')===true,
      managementPermissions:effectiveManagementPermissions(doc.data()), invitedManagementPermissions:doc.get('invitedManagementPermissions')??null,
      principal:doc.get('roles')?.includes('MANAGER')===true&&doc.get('managementDelegated')!==true,
      invitationKind:doc.get('invitationKind')??'OPERATIONAL', linkInvitation:doc.get('linkInvitation')===true,
    }))};
  });
});

export const saveWorkforceRoles = onCall(options, async request => {
  if(request.data?.destinationTenantId!=null)return transferWorkforce(request);
  object(request.data,['tenantId','requestId','userId','roles','managementPermissions'],'Funções');
  const userId=identifier(request.data.userId,'Pessoa');
  if(request.data.managementPermissions != null) {
    if(request.data.roles != null)throw new HttpsError('invalid-argument','Não misture funções e permissões de gestão.');
    const permissions=parseManagementPermissions(request.data.managementPermissions);
    const authorize=async({db,tx,tenantId,access})=>{
      requirePrincipal(access.member.data());
      const member=await tx.get(db.doc('tenants/'+tenantId+'/members/'+userId));
      if(!member.exists || member.get('active')!==true || !member.get('roles')?.includes('MANAGER') || member.get('managementDelegated')!==true)
        throw new HttpsError('permission-denied','Somente o acesso de um gestor delegado ativo pode ser alterado.');
      return member;
    };
    return teamCommand(request,'saveManagementPermissions',{userId,permissions},async context=>{
      const member=await authorize(context);
      context.tx.update(member.ref,{managementPermissions:permissions,...metadata(context.uid,true)});
      context.tx.create(context.db.collection('tenants/'+context.tenantId+'/workforceEvents').doc(),{action:'MANAGEMENT_PERMISSIONS_CHANGED',actorUid:context.uid,targetUid:userId,before:effectiveManagementPermissions(member.data()),after:permissions,createdAt:FieldValue.serverTimestamp()});
      tenantAudit(context.tx,context.db,context.tenantId,'MANAGEMENT_PERMISSIONS_CHANGED',context.uid,context.access.member.get('name'),{targetUid:userId,after:permissions});
      return {userId,managementPermissions:permissions};
    },['MANAGER'],authorize);
  }
  if(!Array.isArray(request.data.roles)||!request.data.roles.length||new Set(request.data.roles).size!==request.data.roles.length||request.data.roles.some(r=>!operationalRoles.includes(r)))
    throw new HttpsError('invalid-argument','Escolha funções operacionais. Para retirar o acesso, use Desvincular.');
  const roles=operationalRoles.filter(r=>request.data.roles.includes(r));
  return teamCommand(request,'saveWorkforceRoles',{userId,roles},async({db,tx,tenantId,uid,access})=>{
    requirePrincipal(access.member.data());
    const ref=db.doc('tenants/'+tenantId+'/members/'+userId), member=await tx.get(ref);
    if(!member.exists||member.get('active')!==true||member.get('unlinkedAt'))throw new HttpsError('failed-precondition','A pessoa precisa aceitar um novo convite.');
    requireEditableWorkforceMember(member.data());
    if(member.get('roles')?.includes('MANAGER')||!member.get('roles')?.some(r=>operationalRoles.includes(r)))throw new HttpsError('permission-denied','Este vínculo não é um funcionário operacional.');
    const oldRoles=member.get('roles')??[], professionalId=member.get('professionalId');
    if(roles.includes('PROFESSIONAL')&&!oldRoles.includes('PROFESSIONAL'))throw new HttpsError('failed-precondition','A função profissional exige um novo convite vinculado ao cadastro correto.');
    const professional=professionalId?await tx.get(db.doc('tenants/'+tenantId+'/professionals/'+identifier(professionalId,'Profissional'))):null;
    if(roles.includes('PROFESSIONAL')&&(!professional?.exists||professional.get('active')!==true||professional.get('authUid')&&professional.get('authUid')!==userId||professional.get('formerAuthUid')&&professional.get('formerAuthUid')!==userId))throw new HttpsError('failed-precondition','Cadastro profissional indisponível.');
    const unassigned=roles.includes('PROFESSIONAL')?await prepareProfessionalAppointments(tx,db,tenantId,professionalId):[];
    const removesProfessional=oldRoles.includes('PROFESSIONAL')&&!roles.includes('PROFESSIONAL');
    await requireNoOpenAssignments(tx,db,tenantId,{professionalUid:removesProfessional?userId:null,professionalId:removesProfessional?professionalId:null,driverUid:oldRoles.includes('DRIVER')&&!roles.includes('DRIVER')?userId:null});
    const retained=oldRoles.filter(r=>!operationalRoles.includes(r));
    tx.update(ref,{roles:[...new Set([...retained,...roles])],...(removesProfessional?{professionalId:FieldValue.delete()}:{}),...metadata(uid,true)});
    if(roles.includes('PROFESSIONAL')) {tx.update(professional.ref,{authUid:userId,...metadata(uid,true)});writeProfessionalAppointments(tx,unassigned,userId,uid);}
    if(removesProfessional&&professional?.exists&&professional.get('authUid')===userId)tx.update(professional.ref,{authUid:FieldValue.delete(),formerAuthUid:userId,active:false,...metadata(uid,true)});
    tx.create(db.collection('tenants/'+tenantId+'/workforceEvents').doc(),{actorUid:uid,targetUid:userId,action:'ROLES_CHANGED',before:oldRoles,after:[...retained,...roles],createdAt:FieldValue.serverTimestamp()});
    tenantAudit(tx,db,tenantId,'ROLES_CHANGED',uid,access.member.get('name'),{targetUid:userId,before:oldRoles,after:[...retained,...roles]});
    return{userId,roles:[...retained,...roles]};
  },['MANAGER'],async({access})=>requirePrincipal(access.member.data()));
});

export const unlinkWorkforceMember = onCall(options, async request => {
  object(request.data,['tenantId','requestId','userId','professionalId','confirmed'],'Desvinculação');
  if(request.data.confirmed!==true || !!request.data.userId===!!request.data.professionalId)throw new HttpsError('invalid-argument','Confirme a pessoa ou cadastro que será desvinculado.');
  const userId=request.data.userId?identifier(request.data.userId,'Pessoa'):null;
  const professionalId=request.data.professionalId?identifier(request.data.professionalId,'Profissional'):null;
  return teamCommand(request,'unlinkWorkforceMember',{userId,professionalId,confirmed:true},async({db,tx,tenantId,uid,access})=>{
    requirePrincipal(access.member.data());
    const requestedPro=professionalId?await tx.get(db.doc('tenants/'+tenantId+'/professionals/'+professionalId)):null;
    if(requestedPro&&!requestedPro.exists)throw new HttpsError('not-found','Cadastro não encontrado neste petshop.');
    const targetUid=userId??requestedPro?.get('authUid')??null;
    const member=targetUid?await tx.get(db.doc('tenants/'+tenantId+'/members/'+targetUid)):null;
    if(targetUid){
      if(!member?.exists || !member.get('roles')?.some(r=>['MANAGER',...operationalRoles].includes(r)))throw new HttpsError('not-found','Vínculo de equipe não encontrado.');
      if(targetUid===uid || member.get('roles')?.includes('MANAGER')&&member.get('managementDelegated')!==true)throw new HttpsError('permission-denied','O acesso do gestor principal é protegido.');
      if(member.get('staffInvitationPending')||member.get('activationPending'))throw new HttpsError('failed-precondition','Revogue o convite pendente em vez de desvincular.');
    }
    const proIds=new Set([professionalId,member?.get('professionalId')].filter(Boolean));
    if(targetUid){const linked=await tx.get(db.collection('tenants/'+tenantId+'/professionals').where('authUid','==',targetUid).limit(3));if(linked.size>2)throw new HttpsError('failed-precondition','Cadastros vinculados exigem revisão.');for(const doc of linked.docs)proIds.add(doc.id);}
    const professionals=[];
    for(const id of proIds){const doc=requestedPro?.id===id?requestedPro:await tx.get(db.doc('tenants/'+tenantId+'/professionals/'+id));if(doc.exists){if(doc.get('authUid')&&doc.get('authUid')!==targetUid)throw new HttpsError('failed-precondition','O vínculo profissional mudou. Atualize a lista.');professionals.push(doc);}}
    if(!targetUid&&(!requestedPro||requestedPro.get('active')!==true))throw new HttpsError('failed-precondition','Cadastro já está desvinculado.');
    await requireNoOpenAssignments(tx,db,tenantId,{professionalUid:targetUid,professionalId:null,driverUid:targetUid});
    for(const doc of professionals)await requireNoOpenAssignments(tx,db,tenantId,{professionalUid:null,professionalId:doc.id,driverUid:null});
    for(const doc of professionals)tx.update(doc.ref,{active:false,authUid:FieldValue.delete(),...(targetUid?{formerAuthUid:targetUid}:{}),...metadata(uid,true)});
    if(member){
      const roles=(member.get('roles')??[]).filter(r=>!['MANAGER',...operationalRoles].includes(r));
      const active=member.get('active')===true&&roles.length>0;
      tx.update(member.ref,{roles,active,professionalId:FieldValue.delete(),managementDelegated:FieldValue.delete(),managementPermissions:FieldValue.delete(),unlinkedAt:FieldValue.serverTimestamp(),...metadata(uid,true)});
      const link=db.doc('users/'+targetUid+'/tenantLinks/'+tenantId);if(active)tx.set(link,{});else tx.delete(link);
    }
    tx.create(db.collection('tenants/'+tenantId+'/workforceEvents').doc(),{actorUid:uid,targetUid,professionalId,action:'UNLINKED',createdAt:FieldValue.serverTimestamp()});
    tenantAudit(tx,db,tenantId,'UNLINKED',uid,access.member.get('name'),{targetUid:targetUid??null,professionalId:professionalId??null});
    return{userId:targetUid,professionalId,unlinked:true};
  },['MANAGER'],async({access})=>requirePrincipal(access.member.data()));
});
