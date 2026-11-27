/// The Tutor PWA of the staging project, published on Firebase Hosting in the
/// site declared in firebase.json.
const stagingTutorAppUrl = 'https://caopanheiro-app.web.app';

const _givenTutorAppUrl = String.fromEnvironment('TUTOR_APP_URL');
const _buildEnvironment = String.fromEnvironment(
  'CAOPANHEIRO_ENV',
  defaultValue: 'local',
);

/// Public address of the Tutor PWA. `--dart-define=TUTOR_APP_URL=https://...`
/// chooses it; without it a staging build uses [stagingTutorAppUrl] and a
/// local build offers only the code, since no address of the computer is
/// guessed.
const configuredTutorAppUrl = _givenTutorAppUrl != ''
    ? _givenTutorAppUrl
    : _buildEnvironment == 'staging'
    ? stagingTutorAppUrl
    : '';

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
