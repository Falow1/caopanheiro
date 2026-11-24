import { HttpsError } from 'firebase-functions/v2/https';

// Old appointments are projected without inventing individual times or authors.
export function executionItems(appointment) {
  return (appointment.items ?? []).map(item => ({...item, execution: item.execution ?? {
    status: appointment.status, history: [], legacyInherited: true,
  }}));
}

export function aggregateExecution(items) {
  const statuses = items.map(item => item.execution.status);
  if (statuses.length && statuses.every(status => status === 'COMPLETED')) return 'COMPLETED';
  if (statuses.some(status => ['IN_PROGRESS','COMPLETED'].includes(status))) return 'IN_PROGRESS';
  return 'PET_RECEIVED';
}

export function changePetExecution(appointment, petId, status, uid, at) {
  if (!['IN_PROGRESS','COMPLETED'].includes(status)) throw new HttpsError('invalid-argument','Ação individual inválida.');
  const items = executionItems(appointment);
  if (!petId && items.length !== 1) throw new HttpsError('failed-precondition','Escolha o pet para iniciar ou finalizar. Atualize o aplicativo.');
  const id = petId ?? items[0]?.pet.id;
  const selected = items.find(item => item.pet.id === id);
  if (!selected) throw new HttpsError('invalid-argument','O pet não pertence a este agendamento.');
  const expected = status === 'IN_PROGRESS' ? 'PET_RECEIVED' : 'IN_PROGRESS';
  if (selected.execution.status !== expected) throw new HttpsError('failed-precondition','A situação deste pet mudou. Atualize o atendimento.');
  const updated = items.map(item => item.pet.id !== id ? item : ({...item, execution: {
    ...item.execution, status,
    [status === 'IN_PROGRESS' ? 'startedAt' : 'completedAt']: at,
    [status === 'IN_PROGRESS' ? 'startedBy' : 'completedBy']: uid,
    history: [...(item.execution.history ?? []), {status,at,actorUid:uid}],
  }}));
  return {items:updated,status:aggregateExecution(updated)};
}

export function returnReadiness(appointment, pets) {
  const items = executionItems(appointment);
  const legacyReady = appointment.status === 'COMPLETED' && items.length > 0 && items.every(item=>item.execution.status==='COMPLETED');
  return pets.map(pet => ({...pet, species:items.find(item=>pet.id&&item.pet.id===pet.id)?.pet.species||pet.species||'', serviceStatus:pet.id ? (items.find(item => item.pet.id === pet.id)?.execution.status ?? null) : (legacyReady?'COMPLETED':null)}));
}

export function requireReturnReady(appointment, pets) {
  if (!pets?.length || returnReadiness(appointment,pets).some(pet => pet.serviceStatus !== 'COMPLETED')) {
    throw new HttpsError('failed-precondition','Aguarde a conclusão do atendimento de todos os pets deste transporte antes do retorno.');
  }
}
