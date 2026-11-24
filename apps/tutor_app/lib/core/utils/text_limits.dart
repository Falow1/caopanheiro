import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Length the backend validates: String.length (UTF-16 code units) is the same
/// in Dart and JavaScript, while TextField.maxLength counts visible
/// characters, so an emoji would fit on screen and be refused on confirmation.
int serverTextLength(String value) => value.length;

/// Limits the field by [serverTextLength], never splitting a visible
/// character; text over the limit keeps the characters that fit.
class ServerLengthFormatter extends TextInputFormatter {
  const ServerLengthFormatter(this.max);
  final int max;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (serverTextLength(newValue.text) <= max) return newValue;
    final fitted = StringBuffer();
    for (final character in newValue.text.characters) {
      if (fitted.length + character.length > max) break;
      fitted.write(character);
    }
    final text = fitted.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: newValue.selection.end.clamp(0, text.length),
      ),
    );
  }
}
