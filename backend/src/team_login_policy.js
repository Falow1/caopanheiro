import {randomBytes} from 'node:crypto';
import {HttpsError} from 'firebase-functions/v2/https';
import {digest} from './runtime.js';
import { purgeAt, retention } from './retention.js';
export const loginPolicy={batch:5,minimumMs:300,delays:[30000,60000,300000,900000,1800000,3600000]};
export const lookupPolicy={batch:30,minimumMs:500,delays:[60000]};
export const mailPolicy={batch:5,minimumMs:60000,delays:[3600000]};
export function reserveState(previous,now,policy,reservation){
 let state=previous&&now-(previous.lastAt??0)<86400000?previous:{};
 if((state.nextAt??0)>now)return {retryAfterMs:state.nextAt-now};
 if(policy.windowMs&&now-(state.windowStart??0)>=policy.windowMs)state={...state,count:0,windowStart:now};
 const count=(state.count??0)+1,level=state.level??0,blocked=count>=policy.batch;
 const delay=blocked?policy.delays[Math.min(level,policy.delays.length-1)]:policy.minimumMs;
 return{value:{count:blocked?0:count,level:blocked?Math.min(level+1,policy.delays.length-1):level,nextAt:now+delay,lastAt:now,windowStart:state.windowStart??now,expiresAt:new Date(now+86400000),reservation},retryAfterMs:0,delay};
}
export function retryError(ms){return new HttpsError('resource-exhausted','Aguarde antes de tentar novamente.',{reason:'LOGIN_THROTTLED',retryAfterMs:Math.max(1,Math.ceil(ms))});}
export async function reserveAttempt(db,group,email,source,policy,now=Date.now()){
 const reservation=randomBytes(16).toString('hex');
 const refs=['email:'+email,'source:'+source].map(key=>db.doc(`teamAuthLimits/${digest(JSON.stringify([group,key]))}`));
 return db.runTransaction(async tx=>{
  const docs=await tx.getAll(...refs),states=docs.map((doc,index)=>reserveState(doc.data(),now,index===0?policy:{...policy,batch:policy.batch*10,minimumMs:0,windowMs:60000},reservation));
  const wait=Math.max(...states.map(state=>state.retryAfterMs));if(wait>0)throw retryError(wait);
  states.forEach((state,index)=>tx.set(refs[index],{...state.value,purgeAt:purgeAt(retention.limit,now)}));
  return{emailRef:refs[0],reservation,retryAfterMs:Math.max(...states.map(state=>state.delay))};
 });
}
export async function clearSuccessfulEmail(db,attempt){
 await db.runTransaction(async tx=>{const current=await tx.get(attempt.emailRef);if(current.get('reservation')===attempt.reservation)tx.set(attempt.emailRef,{count:0,level:0,nextAt:Date.now()+300,lastAt:Date.now(),expiresAt:new Date(Date.now()+86400000),reservation:attempt.reservation,purgeAt:purgeAt(retention.limit)});});
}
