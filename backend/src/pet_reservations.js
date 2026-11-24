export async function reservationState(tx,db,tenantId,doc){
 const state=doc.data()??{},reservations={...state.reservations};
 const missing=Object.entries(reservations).filter(([,value])=>!value.customerId||!Array.isArray(value.petIds));
 if(missing.length){
  const appointments=await tx.getAll(...missing.map(([id])=>db.doc(`tenants/${tenantId}/appointments/${id}`)));
  for(let i=0;i<appointments.length;i++)if(appointments[i].exists){const value=appointments[i].data();reservations[missing[i][0]]={...missing[i][1],customerId:value.customerId,petIds:(value.items??[]).map(item=>item.pet.id)};}
 }
 return {...state,reservations};
}
export function samePet(booking,reservation){
 return reservation.customerId===booking.customer.id&&reservation.petIds?.some(id=>booking.items.some(item=>item.pet.id===id));
}
