// Export of a petshop's data (E2): customers, pets and appointments as CSV
// files for the principal manager to keep. It is a copy: nothing is changed or
// deleted on the platform. Each export is recorded in the platform audit,
// with counts only.
import { HttpsError } from 'firebase-functions/v2/https';
import { onCall } from './callable.js';
import { actor, identifier, localBackend, object, options, teamAccess } from './runtime.js';
import { ACCESS_PAUSED, principalMember } from './access_policy.js';
import { tenantAudit } from './tenant_audit.js';
import { normalizedPet } from './pet_policy.js';

export const MAX_EXPORT_CUSTOMERS = 2000;
export const MAX_EXPORT_APPOINTMENTS = 5000;
const statusLabels = { REQUESTED: 'Pedido', CONFIRMED: 'Confirmado', PET_RECEIVED: 'Pet recebido', IN_PROGRESS: 'Em atendimento',
  COMPLETED: 'Concluído', CANCELLED: 'Cancelado', NO_SHOW: 'Não compareceu' };

/// One CSV field: separator ";" (opens in spreadsheets set to Portuguese),
/// quotes when needed, and a leading apostrophe so that a text starting with
/// =, +, - or @ is never read as a formula by the spreadsheet.
export function csvField(value) {
  let text = value == null ? '' : String(value);
  if (/^[=+\-@\t\r]/.test(text)) text = `'${text}`;
  return /[";\r\n]/.test(text) ? `"${text.replaceAll('"', '""')}"` : text;
}
export const csvTable = (header, rows) => [header, ...rows].map((row) => row.map(csvField).join(';')).join('\r\n') + '\r\n';
const money = (cents) => Number.isSafeInteger(cents) ? (cents / 100).toFixed(2).replace('.', ',') : '';

/// The three files from the stored documents (pure, tested without the emulator).
export function exportFiles(customers, appointments) {
  const ordered = [...customers].sort((a, b) => (a.recordNumber ?? 0) - (b.recordNumber ?? 0) || String(a.name).localeCompare(String(b.name), 'pt-BR'));
  const customerRows = ordered.map((item) => [item.recordNumber ?? '', item.name ?? '', item.phone ?? '', item.email ?? '', item.tutorUid ? 'Sim' : 'Não']);
  // Breed and size from the list; the text of a pet saved before the list
  // that was not found on it goes in its own column.
  const petRows = ordered.flatMap((item) => Object.values(item.pets ?? {}).map(normalizedPet)
    .sort((a, b) => String(a.name).localeCompare(String(b.name), 'pt-BR'))
    .map((pet) => [item.recordNumber ?? '', item.name ?? '', pet.recordNumber ?? '', pet.name ?? '', pet.species ?? '', pet.breed ?? '',
      pet.size ?? '', pet.legacyBreed ?? '', pet.birthDate ?? '', pet.notes ?? '']));
  const appointmentRows = [...appointments].sort((a, b) => String(a.localStartsAt ?? '').localeCompare(String(b.localStartsAt ?? '')))
    .map((item) => {
      const local = String(item.localStartsAt ?? '');
      return [item.recordNumber ?? '', local.slice(0, 10), local.slice(11, 16), item.customer?.name ?? '',
        (item.items ?? []).map((entry) => entry.pet?.name).filter(Boolean).join(', '),
        (item.items ?? []).flatMap((entry) => (entry.services ?? []).map((service) => service.name)).filter(Boolean).join(', '),
        item.professional ?? '', statusLabels[item.status] ?? item.status ?? '', money(item.priceCents), item.durationMinutes ?? ''];
    });
  return {
    files: [
      { name: 'clientes.csv', content: csvTable(['Número', 'Nome', 'Telefone', 'E-mail', 'Usa o app'], customerRows) },
      { name: 'pets.csv', content: csvTable(['Número do cliente', 'Cliente', 'Número do pet', 'Pet', 'Espécie', 'Raça', 'Porte', 'Raça informada antes da lista', 'Nascimento', 'Observações'], petRows) },
      { name: 'agendamentos.csv', content: csvTable(['Número', 'Data', 'Hora', 'Cliente', 'Pets', 'Serviços', 'Profissional', 'Situação', 'Valor (R$)', 'Duração (min)'], appointmentRows) },
    ],
    counts: { customers: customerRows.length, pets: petRows.length, appointments: appointmentRows.length },
  };
}

export const exportTenantData = onCall(options, async (request) => {
  const db = localBackend(); const uid = await actor(request);
  object(request.data, ['tenantId'], 'Exportação');
  const tenantId = identifier(request.data.tenantId, 'Empresa');
  // Authorization first, then plain reads: the export never writes the data.
  const access = await db.runTransaction(async (tx) => teamAccess(tx, db, tenantId, uid, ['MANAGER'], { pausedPrincipal: true }));
  if (!principalMember(access.member.data())) throw new HttpsError('permission-denied', 'Somente o gestor principal exporta os dados do petshop.');
  // A platform suspension keeps only Support and the plan open.
  if (access.paused === 'SUSPENDED') throw new HttpsError('permission-denied', ACCESS_PAUSED, { reason: 'ACCESS_PAUSED' });
  const [customers, appointments] = await Promise.all([
    db.collection(`tenants/${tenantId}/customers`).limit(MAX_EXPORT_CUSTOMERS + 1).get(),
    db.collection(`tenants/${tenantId}/appointments`).limit(MAX_EXPORT_APPOINTMENTS + 1).get(),
  ]);
  if (customers.size > MAX_EXPORT_CUSTOMERS || appointments.size > MAX_EXPORT_APPOINTMENTS) {
    throw new HttpsError('resource-exhausted', 'Há registros demais para exportar de uma vez. Fale com o Suporte da plataforma.');
  }
  const result = exportFiles(customers.docs.map((doc) => doc.data()), appointments.docs.map((doc) => doc.data()));
  const batch = db.batch();
  tenantAudit(batch, db, tenantId, 'DATA_EXPORTED', uid, access.member.get('name') ?? 'Gestor principal', result.counts);
  await batch.commit();
  return { tenantId, tenantName: access.tenant.get('tradeName') ?? tenantId, exportedAt: new Date().toISOString(), ...result };
});
