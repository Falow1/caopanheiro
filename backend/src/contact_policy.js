// Brazilian phone accepted by every command that receives one (own account,
// customer, team, manager activation, petshop and transport): only the shape
// is checked, the number is not verified. Phones saved before stay as they
// were until the record is saved again. packages/caopanheiro_core/lib/src/
// brazil_phone.dart applies the same rule while the person types.
import { invalid } from './runtime.js';

// Area codes (DDD) in use in Brazil.
const areaCodes = new Set([
  11, 12, 13, 14, 15, 16, 17, 18, 19, 21, 22, 24, 27, 28, 31, 32, 33, 34, 35, 37, 38,
  41, 42, 43, 44, 45, 46, 47, 48, 49, 51, 53, 54, 55, 61, 62, 63, 64, 65, 66, 67, 68, 69,
  71, 73, 74, 75, 77, 79, 81, 82, 83, 84, 85, 86, 87, 88, 89, 91, 92, 93, 94, 95, 96, 97, 98, 99,
]);

export const PHONE_MESSAGE = 'Telefone inválido. Informe o DDD e o número, como (11) 91234-5678.';

// DDD in use and a number of 8 or 9 digits that does not start with 0 or 1
// (numbers starting with 8 included); the country code 55 is optional.
// Returns (DD) NNNNN-NNNN, or null.
export function formatBrazilPhone(value) {
  if (typeof value !== 'string' || value.length > 32 || !/^[+()\d\s.-]*$/.test(value)) return null;
  let digits = value.replace(/\D/g, '');
  if (digits.length > 11 && digits.startsWith('55')) digits = digits.slice(2);
  if (digits.length !== 10 && digits.length !== 11) return null;
  if (!areaCodes.has(Number(digits.slice(0, 2)))) return null;
  const local = digits.slice(2);
  if (!/^[2-9]/.test(local)) return null;
  const split = local.length - 4;
  return `(${digits.slice(0, 2)}) ${local.slice(0, split)}-${local.slice(split)}`;
}

export function brazilPhone(value) {
  return formatBrazilPhone(value) ?? invalid(PHONE_MESSAGE);
}
