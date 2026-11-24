import {getAuth} from 'firebase-admin/auth';
import {HttpsError} from 'firebase-functions/v2/https';
import {onCall} from './callable.js';
import {localBackend,options,object,email,tenantEnabled,tenantOpen} from './runtime.js';
import {ACCESS_PAUSED,companySuspended,principalMember} from './access_policy.js';
import {pendingStaff} from './staff_invitation_policy.js';
import {pendingManager} from './manager_activation.js';
import {reserveAttempt,clearSuccessfulEmail,loginPolicy,lookupPolicy,mailPolicy} from './team_login_policy.js';
import {checkPassword,sendPasswordEmail} from './password_check.js';
const source=request=>request.rawRequest.ip||request.rawRequest.socket?.remoteAddress||'unknown';
const denied=ms=>new HttpsError('unauthenticated','E-mail ou senha incorretos.',{reason:'LOGIN_DENIED',retryAfterMs:ms});
async function accountFor(contact){try{return await getAuth().getUserByEmail(contact);}catch(error){if(error.code==='auth/user-not-found')return null;throw new HttpsError('unavailable','Não foi possível consultar o acesso. Tente novamente.');}}
async function linksFor(db,account){
 if(!account||account.disabled)return{pending:false,active:false};
 const links=await db.collection(`users/${account.uid}/tenantLinks`).limit(51).get();
 if(links.size>50)throw new HttpsError('failed-precondition','Vínculos precisam de revisão administrativa.');
 let pending=false,managerPending=false,active=false,blocked=false,pausedPrincipal=false;
 for(const link of links.docs){
  const [tenant,member,subscription]=await db.getAll(db.doc(`tenants/${link.id}`),db.doc(`tenants/${link.id}/members/${account.uid}`),db.doc(`subscriptions/${link.id}`));
  if(!(await tenantOpen(db,db,tenant,subscription))){
   const staff=tenant.exists&&member.get('active')===true&&!!member.get('roles')?.some(role=>['MANAGER','ATTENDANT','PROFESSIONAL','DRIVER'].includes(role));
   blocked ||= staff;
   // Paused by the platform or by an expired plan (E2): the principal manager
   // still enters, for the plan, Support and the export.
   pausedPrincipal ||= staff&&principalMember(member.data())&&(companySuspended(tenant.data())||tenantEnabled(tenant,subscription));
   continue;
  }
  managerPending ||= pendingManager(member.data())&&member.get('email')===account.email?.toLowerCase();
  pending ||= (pendingManager(member.data())||pendingStaff(member.data()))&&member.get('email')===account.email?.toLowerCase();
  active ||= member.get('active')===true&&member.get('roles')?.some(role=>['MANAGER','ATTENDANT','PROFESSIONAL','DRIVER'].includes(role));
 }
 return{pending,managerPending,active,blocked,pausedPrincipal};
}
export const inspectTeamLogin=onCall(options,async request=>{
 object(request.data,['email'],'Acesso');const contact=email(request.data.email),db=localBackend();
 await reserveAttempt(db,'lookup',contact,source(request),lookupPolicy);
 const account=await accountFor(contact),links=await linksFor(db,account);
 // The requested invitation hint is restricted to valid manager invitations;
 // no UID, company, profile, password state or general account directory leaks.
 return{mode:links.managerPending?'INVITATION':'PASSWORD'};
});
export const loginTeam=onCall(options,async request=>{
 object(request.data,['email','password'],'Acesso');const contact=email(request.data.email),password=request.data.password;
 if(typeof password!=='string'||!password.length||password.length>4096)throw denied(300);
 const db=localBackend(),attempt=await reserveAttempt(db,'login',contact,source(request),loginPolicy);
 let response;
 try{
  response=await checkPassword(contact,password);
 }catch{throw new HttpsError('unavailable','Não foi possível conectar ao serviço de acesso. Tente novamente.');}
 if(!response.ok){const result=await response.json();if(['EMAIL_NOT_FOUND','INVALID_PASSWORD','INVALID_LOGIN_CREDENTIALS','USER_DISABLED'].includes(result.error?.message))throw denied(attempt.retryAfterMs);throw new HttpsError('unavailable','Não foi possível confirmar o acesso. Tente novamente.');}
 const authenticated=await response.json(),account=await accountFor(contact),links=await linksFor(db,account);
 if(!account||account.uid!==authenticated.localId)throw denied(attempt.retryAfterMs);
 if(!links.active&&!links.pending&&!links.pausedPrincipal){
  if(!links.blocked)throw denied(attempt.retryAfterMs);
  // The password was verified: explaining the pause reveals nothing to a
  // stranger and must not count as a failed attempt.
  await clearSuccessfulEmail(db,attempt);
  throw new HttpsError('failed-precondition',ACCESS_PAUSED,{reason:'COMPANY_UNAVAILABLE'});
 }
 const token=await getAuth().createCustomToken(account.uid);
 await clearSuccessfulEmail(db,attempt);
 return{customToken:token};
});
export const requestTeamLoginEmail=onCall(options,async request=>{
 object(request.data,['email','purpose'],'E-mail');const contact=email(request.data.email),purpose=request.data.purpose;
 if(!['INVITATION','PASSWORD_RESET'].includes(purpose))throw new HttpsError('invalid-argument','Solicitação inválida.');
 const db=localBackend();await reserveAttempt(db,'mail',contact,source(request),mailPolicy);
 const account=await accountFor(contact),links=await linksFor(db,account);
 if(account&&(purpose==='INVITATION'?links.pending:links.pending||links.active)){
  // Auth sends its own e-mail: the link never passes through the backend.
  let sent;try{sent=await sendPasswordEmail(contact);}catch{sent=null;}
  if(!sent?.ok)throw new HttpsError('unavailable','Não foi possível enviar o e-mail agora. Tente novamente.');
 }
 return{accepted:true};
});
