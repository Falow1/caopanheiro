import { HttpsError } from 'firebase-functions/v2/https';
import { minute, zonedInstant } from './calendar.js';

export function blockStartsAt(block, zone) {
  return block?.date ? zonedInstant(block.date, block.fullDay ? 0 : minute(block.start), zone) : null;
}
export function blockIsFuture(block, zone, now = Date.now()) {
  const start = blockStartsAt(block, zone);
  return start != null && start > now;
}

export function canEditBlock(roles, uid, block, zone, now = Date.now()) {
  return roles.includes('MANAGER') ||
    (roles.includes('ATTENDANT') && block?.createdBy === uid && blockIsFuture(block, zone, now));
}

export function authorizeBlock(roles, uid, existing, proposed, zone) {
  if (roles.includes('MANAGER')) return;
  if (!roles.includes('ATTENDANT') || (existing && !canEditBlock(roles, uid, existing, zone))) {
    throw new HttpsError('permission-denied', 'Você só pode alterar ou remover seus próprios bloqueios futuros. Procure o gestor.', {reason:'BLOCK_SCOPE'});
  }
  if (proposed && !blockIsFuture(proposed, zone)) {
    throw new HttpsError('failed-precondition', 'Escolha um período futuro para o bloqueio.');
  }
}
