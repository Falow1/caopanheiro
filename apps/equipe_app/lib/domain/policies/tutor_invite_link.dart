/// Public address of the Tutor PWA, supplied at build time with
/// `--dart-define=TUTOR_APP_URL=https://...`. Without it only the code is
/// offered: the app never invents an address.
const configuredTutorAppUrl = String.fromEnvironment('TUTOR_APP_URL');

/// Link that opens the Tutor PWA with the invite already filled in, or null
/// when no valid http(s) address is configured.
String? tutorInviteLink(String code, {String base = configuredTutorAppUrl}) {
  final address = Uri.tryParse(base.trim());
  if (address == null ||
      !address.hasAuthority ||
      !const ['http', 'https'].contains(address.scheme)) {
    return null;
  }
  return address
      .replace(
        queryParameters: {...address.queryParameters, 'convite': code},
        fragment: '',
      )
      .toString()
      .replaceFirst(RegExp(r'#$'), '');
}
