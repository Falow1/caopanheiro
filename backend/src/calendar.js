import { invalid, object, text } from './runtime.js';

export function dayValue(value) {
  const day = text(value, 'Data', 10, 10);
  const date = new Date(`${day}T00:00:00.000Z`);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(day) || !Number.isFinite(date.getTime()) || date.toISOString().slice(0, 10) !== day) invalid('Data inválida.');
  return day;
}
export function minute(value) {
  if (typeof value !== 'string' || !/^([01]\d|2[0-3]):[0-5]\d$/.test(value)) invalid('Horário deve ter o formato HH:mm.');
  const [hour, minute] = value.split(':').map(Number); return hour * 60 + minute;
}
export function timeLabel(value) { return `${String(Math.floor(value / 60)).padStart(2, '0')}:${String(value % 60).padStart(2, '0')}`; }
export function weekDays(value) {
  object(value, ['1','2','3','4','5','6','7'], 'Dias');
  const result = {};
  for (let day = 1; day <= 7; day++) {
    const periods = value[day] ?? [];
    if (!Array.isArray(periods) || periods.length > 4) invalid('Informe até quatro períodos por dia.');
    result[day] = periods.map((period) => {
      object(period, ['start','end'], 'Período');
      const start = minute(period.start); const end = minute(period.end);
      if (start >= end) invalid('O fim do período deve ser posterior ao início.');
      return { start, end };
    }).sort((a,b) => a.start - b.start);
    if (result[day].some((period,index) => index && result[day][index-1].end > period.start)) invalid('Os períodos não podem se sobrepor.');
  }
  return result;
}
export function jsonDays(value) {
  return Object.fromEntries(Object.entries(value ?? {}).map(([day, periods]) => [day, periods.map((period) => ({ start: timeLabel(period.start), end: timeLabel(period.end) }))]));
}
export function timeZone(value) {
  const zone = text(value, 'Fuso horário', 80, 1);
  try { new Intl.DateTimeFormat('en', { timeZone: zone }).format(new Date()); }
  catch { invalid('Fuso horário inválido.'); }
  return zone;
}
export function civil(timestamp, zone) {
  const parts = new Intl.DateTimeFormat('sv-SE', { timeZone: zone, year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit', hourCycle:'h23' }).formatToParts(new Date(timestamp));
  const values = Object.fromEntries(parts.map((part) => [part.type,part.value]));
  const day = `${values.year}-${values.month}-${values.day}`;
  return { day, minute: Number(values.hour)*60+Number(values.minute), weekDay: new Date(`${day}T12:00:00Z`).getUTCDay() || 7 };
}
export function zonedInstant(day, value, zone) {
  const desired = Date.parse(`${day}T${timeLabel(value)}:00.000Z`);
  let result = desired;
  for (let i=0;i<3;i++) {
    const actual = civil(result, zone);
    const represented = Date.parse(`${actual.day}T${timeLabel(actual.minute)}:00.000Z`);
    result += desired - represented;
  }
  const checked = civil(result, zone);
  return checked.day === day && checked.minute === value ? result : null;
}
export const overlaps = (a,b) => a.start < b.end && b.start < a.end;
export function within(periods, start, end) { return (periods ?? []).some((period) => period.start <= start && end <= period.end); }
// Usual zone of each Brazilian state, used when the company has not chosen
// one. Cities outside it (west of Amazonas, Fernando de Noronha) choose the
// zone in the weekly hours.
const stateZones = {
  AC:'America/Rio_Branco', AL:'America/Maceio', AM:'America/Manaus', AP:'America/Belem', BA:'America/Bahia',
  CE:'America/Fortaleza', DF:'America/Sao_Paulo', ES:'America/Sao_Paulo', GO:'America/Sao_Paulo', MA:'America/Fortaleza',
  MG:'America/Sao_Paulo', MS:'America/Campo_Grande', MT:'America/Cuiaba', PA:'America/Belem', PB:'America/Fortaleza',
  PE:'America/Recife', PI:'America/Fortaleza', PR:'America/Sao_Paulo', RJ:'America/Sao_Paulo', RN:'America/Fortaleza',
  RO:'America/Porto_Velho', RR:'America/Boa_Vista', RS:'America/Sao_Paulo', SC:'America/Sao_Paulo', SE:'America/Maceio',
  SP:'America/Sao_Paulo', TO:'America/Araguaina',
};
export const defaultTimeZone = 'America/Cuiaba';
export function stateTimeZone(state) { return stateZones[String(state ?? '').toUpperCase()] ?? null; }
/** Company wall clock of an instant, as "YYYY-MM-DDTHH:mm:00". */
export function localLabel(timestamp, zone) {
  const local = civil(timestamp, zone); return `${local.day}T${timeLabel(local.minute)}:00`;
}
/** Instant of a company wall clock "YYYY-MM-DDTHH:mm[:00]"; null when it does not exist. */
export function localInstant(value, zone) {
  const match = typeof value === 'string' ? /^(\d{4}-\d{2}-\d{2})T([01]\d|2[0-3]):([0-5]\d)(?::00)?$/.exec(value) : null;
  if (!match) return null;
  const day = match[1], date = new Date(`${day}T00:00:00.000Z`);
  if (!Number.isFinite(date.getTime()) || date.toISOString().slice(0, 10) !== day) return null;
  return zonedInstant(day, Number(match[2]) * 60 + Number(match[3]), zone);
}
