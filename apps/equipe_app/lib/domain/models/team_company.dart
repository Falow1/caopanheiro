import 'internal_user.dart';

class TeamCompany {
  const TeamCompany({
    required this.id,
    this.recordNumber,
    required this.name,
    required this.user,
    this.entitlements = const CompanyEntitlements(),
    this.billing,
  });
  final int? recordNumber;
  final String id;
  final String name;
  final InternalUser user;

  /// What the plan of the petshop includes (A1). Absent on older servers and
  /// legacy petshops: then everything stays available, as before.
  final CompanyEntitlements entitlements;

  /// Expired plan (E2): present only near or after the date of the cycle.
  final CompanyBilling? billing;

  TeamCompany withUser(InternalUser value) => TeamCompany(
    id: id,
    recordNumber: recordNumber,
    name: name,
    user: value,
    entitlements: entitlements,
    billing: billing,
  );
}

/// Phase of the plan of a petshop near or after its date (E2). The server
/// decides each command; this only explains the situation on screen.
class CompanyBilling {
  const CompanyBilling({
    required this.phase,
    this.renewsAt,
    this.deadlineAt,
    this.blockFrom,
    this.owner = false,
  });

  static CompanyBilling? fromJson(Object? raw) {
    if (raw is! Map || raw['phase'] is! String) return null;
    DateTime? date(Object? value) =>
        value is String ? DateTime.tryParse(value)?.toLocal() : null;
    return CompanyBilling(
      phase: raw['phase'] as String,
      renewsAt: date(raw['renewsAt']),
      deadlineAt: date(raw['deadlineAt']),
      blockFrom: date(raw['blockFrom']),
      owner: raw['owner'] == true,
    );
  }

  /// WARNING (7 days or less before the date), GRACE (7 normal days after
  /// it), BOOKINGS_PAUSED (no new booking or rescheduling) or BLOCKED.
  final String phase;
  final DateTime? renewsAt;

  /// Last day of the 7 normal days; after it, bookings pause.
  final DateTime? deadlineAt;

  /// When the operation pauses, after the last appointment already booked.
  final DateTime? blockFrom;

  /// The principal manager who holds the subscription: only they pay.
  final bool owner;

  bool get warning => phase == 'WARNING';
  bool get grace => phase == 'GRACE';
  bool get bookingsPaused => phase == 'BOOKINGS_PAUSED';

  /// Whole days until the date, counted on the calendar; 0 on the day.
  int daysLeft(DateTime now) {
    final date = renewsAt;
    if (date == null) return 0;
    final day = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    final days = day.difference(today).inDays;
    return days < 0 ? 0 : days;
  }
}

/// A petshop whose access is paused (E2): by the platform (SUSPENDED) or by
/// an expired plan after the last booked day (BILLING). Only the principal
/// manager sees it, to renew, export, open the plan and Support.
class PausedCompany {
  const PausedCompany({
    required this.id,
    required this.name,
    required this.reason,
    this.owner = false,
    this.billing,
  });

  factory PausedCompany.fromJson(Map<String, dynamic> value) => PausedCompany(
    id: value['id'] as String,
    name: value['name'] as String? ?? '',
    reason: value['reason'] as String? ?? 'BILLING',
    owner: value['owner'] == true,
    billing: CompanyBilling.fromJson(value['billing']),
  );
  final String id;
  final String name;

  /// BILLING or SUSPENDED.
  final String reason;

  /// Holds the subscription: renews and pays.
  final bool owner;
  final CompanyBilling? billing;
  bool get suspended => reason == 'SUSPENDED';
}

/// Plan features read by the screens; the server still decides each command.
class CompanyEntitlements {
  const CompanyEntitlements({this.tutorApp = true, this.transport = true});
  factory CompanyEntitlements.fromJson(Object? raw) {
    if (raw is! Map) return const CompanyEntitlements();
    return CompanyEntitlements(
      tutorApp: raw['tutorApp'] != false,
      transport: raw['transport'] != false,
    );
  }

  /// Tutor invite, fixed link, QR Code and the tutor app.
  final bool tutorApp;

  /// Transport with a driver and its tracking.
  final bool transport;
}

/// Display-only management membership; it cannot be selected for operations.
class ManagementCompany {
  const ManagementCompany({
    required this.id,
    required this.name,
    this.status = 'UNKNOWN',
  });
  final String id;
  final String name;
  final String status;
  String get statusLabel => switch (status) {
    'ACTIVE' => 'Ativa',
    'SUSPENDED' => 'Suspensa',
    'ONBOARDING' => 'Em cadastro',
    'SUBSCRIPTION_EXPIRED' => 'Assinatura expirada',
    'SUBSCRIPTION_CANCELLED' => 'Assinatura cancelada',
    'SUBSCRIPTION_PENDING' => 'Assinatura pendente',
    'AWAITING_PAID_PLAN' => 'Aguardando plano pago',
    'UNAVAILABLE' => 'Indisponível',
    _ => 'Situação indisponível',
  };
}
