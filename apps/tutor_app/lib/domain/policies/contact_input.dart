/// What the Tutor forms accept as a person's name. Only the shape is
/// checked: no form can prove that a name is real. The phone rule and its
/// mask are shared by the three apps (caopanheiro_core) and re-exported here.
library;

export 'package:caopanheiro_core/caopanheiro_core.dart'
    show
        PhoneInputFormatter,
        displayPhone,
        formatBrazilPhone,
        maskPhone,
        phoneDigits,
        phoneError,
        phoneHint,
        phoneValidator;

const personNameError = 'Informe nome e sobrenome, só com letras.';

String normalizePersonName(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ');

/// First name and surname with letters (accents included), apostrophe,
/// hyphen or period; no digits or symbols.
bool validPersonName(String value) {
  final name = normalizePersonName(value);
  if (name.length < 3 || name.length > 100) return false;
  if (!RegExp(r"^[\p{L}\p{M}'’.\- ]+$", unicode: true).hasMatch(name)) {
    return false;
  }
  final words = name.split(' ');
  return words.length >= 2 &&
      words.every((word) => RegExp(r'\p{L}', unicode: true).hasMatch(word));
}

String? personNameValidator(String? value) =>
    validPersonName(value ?? '') ? null : personNameError;

/// Who answers at an address: a first name is enough, still only letters.
String? contactNameValidator(String? value) {
  final name = normalizePersonName(value ?? '');
  final letters = RegExp(r'\p{L}', unicode: true).allMatches(name).length;
  return letters >= 2 &&
          name.length <= 100 &&
          RegExp(r"^[\p{L}\p{M}'’.\- ]+$", unicode: true).hasMatch(name)
      ? null
      : 'Informe o nome do responsável, só com letras.';
}
