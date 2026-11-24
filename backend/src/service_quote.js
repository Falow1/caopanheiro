import {identifier,invalid,object} from './runtime.js';
const ordered=rows=>rows.map(row=>({petId:row.petId,services:[...row.services].sort((a,b)=>a.id.localeCompare(b.id))})).sort((a,b)=>a.petId.localeCompare(b.petId));
export function serviceQuote(items){return ordered(items.map(item=>({petId:item.pet.id,services:item.services.map(service=>({id:service.id,priceCents:service.priceCents,durationMinutes:service.durationMinutes}))})));}
export function normalizeServiceQuote(value){
 if(value==null)return null;
 if(!Array.isArray(value)||!value.length||value.length>10)invalid('Resumo dos serviços inválido.');
 const rows=value.map(row=>{
  object(row,['petId','services'],'Resumo');const petId=identifier(row.petId,'Pet');
  if(!Array.isArray(row.services)||!row.services.length||row.services.length>20)invalid('Resumo dos serviços inválido.');
  const services=row.services.map(service=>{object(service,['id','priceCents','durationMinutes'],'Serviço');const id=identifier(service.id,'Serviço');
   if(!Number.isSafeInteger(service.priceCents)||service.priceCents<0||!Number.isSafeInteger(service.durationMinutes)||service.durationMinutes<=0)invalid('Resumo dos serviços inválido.');
   return{id,priceCents:service.priceCents,durationMinutes:service.durationMinutes};});
  if(new Set(services.map(s=>s.id)).size!==services.length)invalid('Serviço repetido no resumo.');return{petId,services};
 });
 if(new Set(rows.map(row=>row.petId)).size!==rows.length)invalid('Pet repetido no resumo.');return ordered(rows);
}
export function quoteMatches(expected,items){return JSON.stringify(expected)===JSON.stringify(serviceQuote(items));}
