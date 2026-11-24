import { prepareTenantLinks } from './tenant_links.js';
import { HttpsError } from 'firebase-functions/v2/https';
import { FieldValue } from 'firebase-admin/firestore';
import { identifier, object, teamAccess, digest, accountAvailable } from './runtime.js';
import { requirePrincipal } from './staff_privacy.js';
import { requireNoOpenAssignments } from './workforce_access.js';
import { operationalRoles } from './workforce_policy.js';
import { staffSeatOccupied } from './manager_activation.js';
import { allocateRecordNumbers } from './record_numbers.js';
import { teamCommand, metadata } from './team_commands.js';
import { tenantAudit } from './tenant_audit.js';
import { staffMembers } from './staff_members.js';

export async function transferWorkforce(request) {
  object(request.data,['tenantId','requestId','userId','destinationTenantId','confirmed'],'Transferência');
  const userId=identifier(request.data.userId,'Pessoa');
  const destinationTenantId=identifier(request.data.destinationTenantId,'Empresa de destino');
  if(request.data.confirmed!==true||request.data.tenantId===destinationTenantId)throw new HttpsError('invalid-argument','Confirme uma empresa de destino diferente.');
  const authorize=async({tx,db,uid,access})=>{
    requirePrincipal(access.member.data());
    requirePrincipal((await teamAccess(tx,db,destinationTenantId,uid,['MANAGER'])).member.data());
  };
  return teamCommand(request,'transferWorkforceMember',{userId,destinationTenantId,confirmed:true},async context=>{
    const {tx,db,tenantId,uid}=context;
    await authorize(context);
    await accountAvailable(tx,db,userId);
    const sourceRef=db.doc('tenants/'+tenantId+'/members/'+userId);
    const targetRef=db.doc('tenants/'+destinationTenantId+'/members/'+userId);
    const [source,target,destination]=await tx.getAll(sourceRef,targetRef,db.doc('tenants/'+destinationTenantId));
    const roles=source.get('roles')??[];
    const moving=roles.filter(role=>operationalRoles.includes(role));
    if(source.get('active')!==true||!moving.length||roles.includes('MANAGER')||source.get('activationPending')||source.get('staffInvitationPending'))throw new HttpsError('failed-precondition','Selecione um funcionário ativo da empresa de origem.');
    if(target.get('roles')?.includes('MANAGER')||target.get('activationPending')||target.get('staffInvitationPending')||target.get('active')===true&&(target.get('roles')??[]).some(r=>['MANAGER',...operationalRoles].includes(r)))throw new HttpsError('failed-precondition','A pessoa já possui acesso de equipe ou convite no destino.');
    const professionalRole=moving.includes('PROFESSIONAL');
    let sourcePro=null,sourceProId=null,targetPro=null,targetProId=null;
    if(professionalRole){
      sourceProId=identifier(source.get('professionalId'),'Cadastro profissional');
      sourcePro=await tx.get(db.doc('tenants/'+tenantId+'/professionals/'+sourceProId));
      if(!sourcePro.exists||sourcePro.get('active')!==true||sourcePro.get('authUid')!==userId)throw new HttpsError('failed-precondition','Vínculo profissional inconsistente. Atualize a lista.');
      const former=await tx.get(db.collection('tenants/'+destinationTenantId+'/professionals').where('formerAuthUid','==',userId).limit(2));
      if(former.size>1)throw new HttpsError('failed-precondition','Há mais de um cadastro anterior no destino. Solicite revisão.');
      targetProId=former.docs[0]?.id??('pro-'+digest(userId).slice(0,32));
      targetPro=await tx.get(db.doc('tenants/'+destinationTenantId+'/professionals/'+targetProId));
      if(targetPro.get('authUid')&&targetPro.get('authUid')!==userId||targetPro.get('formerAuthUid')&&targetPro.get('formerAuthUid')!==userId)throw new HttpsError('failed-precondition','O cadastro de destino pertence a outra pessoa.');
    }else if(source.get('professionalId')){
      throw new HttpsError('failed-precondition','O vínculo profissional precisa ser revisado antes da transferência.');
    }
    await requireNoOpenAssignments(tx,db,tenantId,{professionalUid:userId,professionalId:sourceProId,driverUid:userId});
    await requireNoOpenAssignments(tx,db,destinationTenantId,{professionalUid:userId,professionalId:targetProId,driverUid:userId});
    const members=await staffMembers(tx,db,destinationTenantId);
    const plan=await tx.get(db.doc('plans/'+identifier(destination.get('planId'),'Plano')));
    if(!plan.exists||plan.get('active')!==true||!Number.isSafeInteger(plan.get('maxUsers'))||members.docs.filter(d=>d.id!==userId&&staffSeatOccupied(d.data())).length>=plan.get('maxUsers'))throw new HttpsError('failed-precondition','Limite de usuários da empresa de destino atingido.');
    if(professionalRole){
      const professionals=await tx.get(db.collection('tenants/'+destinationTenantId+'/professionals').where('active','==',true).limit(101));
      if(!Number.isSafeInteger(plan.get('maxProfessionals'))||targetPro.get('active')!==true&&professionals.size>=plan.get('maxProfessionals'))throw new HttpsError('failed-precondition','Limite de profissionais da empresa de destino atingido.');
    }
    const retained=roles.filter(r=>!operationalRoles.includes(r));
    const writeLinks=await prepareTenantLinks(tx,db,userId,[destinationTenantId],retained.length?[]:[tenantId]);
    const numbers=await allocateRecordNumbers(tx,db,destinationTenantId,[{type:'members',id:userId,recordNumber:target.get('recordNumber')},...(professionalRole?[{type:'professionals',id:targetProId,recordNumber:targetPro.get('recordNumber')}]:[])]);
    writeLinks();
    tx.update(sourceRef,{roles:retained,active:retained.length>0,professionalId:FieldValue.delete(),unlinkedAt:FieldValue.serverTimestamp(),...metadata(uid,true)});
    if(sourcePro)tx.update(sourcePro.ref,{active:false,authUid:FieldValue.delete(),formerAuthUid:userId,...metadata(uid,true)});
    tx.set(targetRef,{name:source.get('name'),phone:source.get('phone')??'',email:source.get('email')??'',roles:[...new Set([...(target.get('roles')??[]).filter(r=>!operationalRoles.includes(r)),...moving])],recordNumber:numbers[0],active:true,professionalId:targetProId??FieldValue.delete(),managementDelegated:false,managementPermissions:FieldValue.delete(),unlinkedAt:FieldValue.delete(),...metadata(uid,target.exists)},{merge:true});
    if(targetPro)tx.set(targetPro.ref,{name:sourcePro.get('name'),specialty:sourcePro.get('specialty')??'Profissional',recordNumber:numbers[1],active:true,authUid:userId,formerAuthUid:FieldValue.delete(),...metadata(uid,targetPro.exists)},{merge:true});
    const sourceLink=db.doc('users/'+userId+'/tenantLinks/'+tenantId);
    if(retained.length)tx.set(sourceLink,{});else tx.delete(sourceLink);
    tx.set(db.doc('users/'+userId+'/tenantLinks/'+destinationTenantId),{});
    for(const id of [tenantId,destinationTenantId])tx.create(db.collection('tenants/'+id+'/workforceEvents').doc(),{action:'TRANSFERRED',actorUid:uid,targetUid:userId,sourceTenantId:tenantId,destinationTenantId,roles:moving,createdAt:FieldValue.serverTimestamp()});
    tenantAudit(tx,db,tenantId,'TRANSFERRED',uid,context.access?.member.get('name'),{targetUid:userId,destinationTenantId,roles:moving});
    return{userId,destinationTenantId,transferred:true};
  },['MANAGER'],authorize);
}
