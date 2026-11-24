import 'package:caopanheiro_core/caopanheiro_core.dart' show formatBrazilPhone;

/// Query parameter carried by Tutor invite links: `https://<pwa>/?convite=<code>`.
const tutorInviteParameter = 'convite';

/// Accepts either a full invite link or the bare code given by the petshop.
/// Returns null when nothing usable was informed.
String? tutorInviteCode(String? input) {
  final value = input?.trim() ?? '';
  if (value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  final fromLink = uri?.queryParameters[tutorInviteParameter]?.trim();
  if (fromLink != null && fromLink.isNotEmpty) return fromLink;
  if (uri != null && uri.hasScheme) return null;
  return value;
}

/// Password length for new Tutor accounts, matching the SaaS policy.
/// Existing accounts keep signing in with the password they already have.
const minPasswordLength = 8;
const maxPasswordLength = 128;

/// Same e-mail shape accepted by the forms; the server validates again.
bool looksLikeEmail(String value) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());

/// Name and phone the server accepts for the account and for a record
/// created by the petshop's fixed link.
bool validContactName(String value) {
  final name = value.trim();
  return name.length >= 2 && name.length <= 100;
}

/// A phone saved before the Brazilian rule that does not fit it counts as
/// missing, so Complete seu cadastro asks for it again.
bool validContactPhone(String value) => formatBrazilPhone(value) != null;
