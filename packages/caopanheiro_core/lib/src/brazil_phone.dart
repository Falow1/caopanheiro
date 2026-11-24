/// Brazilian phone typed in the forms of the three apps. Only the shape is
/// checked: no form can prove that a number is real.
/// backend/src/contact_policy.js applies the same rule on the server.
library;

import 'package:flutter/services.dart';

/// Area codes (DDD) in use in Brazil.
const _areaCodes = {
  11, 12, 13, 14, 15, 16, 17, 18, 19, //
  21, 22, 24, 27, 28, //
  31, 32, 33, 34, 35, 37, 38, //
  41, 42, 43, 44, 45, 46, 47, 48, 49, //
  51, 53, 54, 55, //
  61, 62, 63, 64, 65, 66, 67, 68, 69, //
  71, 73, 74, 75, 77, 79, //
  81, 82, 83, 84, 85, 86, 87, 88, 89, //
  91, 92, 93, 94, 95, 96, 97, 98, 99,
};

const phoneHint = '(11) 91234-5678';
const phoneError = 'Informe o DDD e o número, como (11) 91234-5678.';

/// Digits typed in a phone field, without the country code 55.
String phoneDigits(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  return digits.length > 11 && digits.startsWith('55')
      ? digits.substring(2)
      : digits;
}

/// (DD) NNNNN-NNNN, or (DD) NNNN-NNNN with 8 digits; partial while typing.
String maskPhone(String digits) {
  if (digits.isEmpty) return '';
  if (digits.length <= 2) return '($digits';
  final area = digits.substring(0, 2), local = digits.substring(2);
  if (local.length <= 4) return '($area) $local';
  final split = local.length == 9 ? 5 : 4;
  return '($area) ${local.substring(0, split)}-${local.substring(split)}';
}

/// The phone as (DD) NNNNN-NNNN when it has a DDD in use and a number of
/// 8 or 9 digits that does not start with 0 or 1 (numbers starting with 8
/// included); null otherwise.
String? formatBrazilPhone(String value) {
  if (!RegExp(r'^[+()\d\s.-]*$').hasMatch(value)) return null;
  final digits = phoneDigits(value);
  if (digits.length != 10 && digits.length != 11) return null;
  if (!_areaCodes.contains(int.parse(digits.substring(0, 2)))) return null;
  return RegExp(r'^[2-9]').hasMatch(digits.substring(2))
      ? maskPhone(digits)
      : null;
}

String? phoneValidator(String? value) =>
    formatBrazilPhone(value ?? '') == null ? phoneError : null;

/// A saved phone shown in a field or a list: formatted when it fits, as it
/// was otherwise, so the person sees what to fix.
String displayPhone(String value) => formatBrazilPhone(value) ?? value;

/// Formats the phone while it is typed: only digits, up to 11 after the
/// country code, as (DD) NNNNN-NNNN. Erasing a parenthesis, space or hyphen
/// erases the digit before it, and the cursor stays after the same digit.
class PhoneInputFormatter extends TextInputFormatter {
  const PhoneInputFormatter();

  static final _nonDigit = RegExp(r'\D');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final typed = newValue.text;
    final all = typed.replaceAll(_nonDigit, '');
    // A key pressed on a full number is ignored: twelve digits starting
    // with 55 would otherwise be read as a country code.
    if (all.length == 12 &&
        oldValue.text.replaceAll(_nonDigit, '').length == 11) {
      return oldValue;
    }
    var digits = phoneDigits(typed);
    final offset = newValue.selection.isValid
        ? newValue.selection.extentOffset.clamp(0, typed.length)
        : typed.length;
    // Digits before the cursor, without the country code that was dropped.
    var before =
        typed.substring(0, offset).replaceAll(_nonDigit, '').length -
        (all.length - digits.length);
    if (before < 0) before = 0;
    final erasedMark =
        typed.length < oldValue.text.length &&
        digits == phoneDigits(oldValue.text);
    if (erasedMark && before > 0) {
      digits = digits.substring(0, before - 1) + digits.substring(before);
      before--;
    }
    if (digits.length > 11) digits = digits.substring(0, 11);
    if (before > digits.length) before = digits.length;
    final text = maskPhone(digits);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: _offsetAfter(text, before)),
    );
  }

  /// Position right after the [count]th digit of [text].
  static int _offsetAfter(String text, int count) {
    if (count == 0) return text.isEmpty ? 0 : 1;
    var seen = 0;
    for (var i = 0; i < text.length; i++) {
      if (!_nonDigit.hasMatch(text[i]) && ++seen == count) return i + 1;
    }
    return text.length;
  }
}
