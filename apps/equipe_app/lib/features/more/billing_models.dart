import 'dart:convert';

/// Subscription of the principal manager (A1), as `getBillingOverview`
/// returns it. One subscription covers every petshop of the manager.
class BillingOverview {
  const BillingOverview({
    required this.state,
    required this.planId,
    required this.planName,
    required this.cycleCents,
    required this.tenants,
    required this.plans,
    required this.pendingRequests,
    required this.cancelQuote,
    this.tenantQuote,
    this.renewsAt,
    this.deadlineAt,
    this.cancelAt,
    this.cancelKeepTenantId,
    this.renewalQuote,
    this.onlinePayments = const OnlinePayments(),
  });

  /// Null when the account has no subscription of its own (delegated
  /// manager or legacy petshop): the screen keeps the plan of the petshop.
  static BillingOverview? fromJson(Map<String, dynamic> value) {
    final raw = value['account'];
    if (raw is! Map) return null;
    final account = Map<String, dynamic>.from(raw);
    final cancel = account['cancelAtCycleEnd'] is Map
        ? Map<String, dynamic>.from(account['cancelAtCycleEnd'] as Map)
        : null;
    return BillingOverview(
      state: account['state'] as String? ?? 'NONE',
      planId: account['planId'] as String? ?? '',
      planName: account['planName'] as String? ?? '',
      renewsAt: _date(account['renewsAt']),
      deadlineAt: _date(account['deadlineAt']),
      cycleCents: (account['cycleCents'] as num?)?.toInt() ?? 0,
      cancelAt: _date(cancel?['at']),
      cancelKeepTenantId: cancel?['keepTenantId'] as String?,
      tenants: [
        for (final item in (account['tenants'] as List?) ?? const [])
          BillingTenant.fromJson(Map<String, dynamic>.from(item as Map)),
      ],
      plans: [
        for (final item in (value['plans'] as List?) ?? const [])
          BillingPlanOption.fromJson(Map<String, dynamic>.from(item as Map)),
      ],
      pendingRequests: [
        for (final item in (value['pendingRequests'] as List?) ?? const [])
          BillingRequestInfo.fromJson(Map<String, dynamic>.from(item as Map)),
      ],
      cancelQuote: BillingQuote.fromJson(
        Map<String, dynamic>.from((value['cancelQuote'] as Map?) ?? const {}),
      ),
      tenantQuote: value['tenantQuote'] is Map
          ? TenantQuote.fromJson(
              Map<String, dynamic>.from(value['tenantQuote'] as Map),
            )
          : null,
      renewalQuote: value['renewalQuote'] is Map
          ? RenewalQuote.fromJson(
              Map<String, dynamic>.from(value['renewalQuote'] as Map),
            )
          : null,
      onlinePayments: OnlinePayments.fromJson(value['onlinePayments']),
    );
  }

  /// TRIAL, TRIAL_ENDED, FREE, ACTIVE or PAST_DUE (paid plan after its
  /// date, E2).
  final String state;
  final String planId;
  final String planName;
  final DateTime? renewsAt;

  /// End of the 7 normal days after the date (E2); then bookings pause.
  final DateTime? deadlineAt;

  /// Value of 30 more days of the paid plan; null outside it.
  final RenewalQuote? renewalQuote;

  /// Pix, card and boleto inside the app: off until the payment provider.
  final OnlinePayments onlinePayments;

  /// Monthly value of the cycle: plan price plus the extra petshops.
  final int cycleCents;
  final DateTime? cancelAt;
  final String? cancelKeepTenantId;
  final List<BillingTenant> tenants;
  final List<BillingPlanOption> plans;
  final List<BillingRequestInfo> pendingRequests;

  /// Refund of a cancellation now.
  final BillingQuote cancelQuote;

  /// Extra petshop leaving or coming back to the paid cycle; null outside it.
  final TenantQuote? tenantQuote;

  bool get trial => state == 'TRIAL';
  bool get free => state == 'FREE';
  bool get paid => state == 'ACTIVE' || state == 'PAST_DUE';
  bool get pastDue => state == 'PAST_DUE';
  bool get canCancel =>
      ['TRIAL', 'TRIAL_ENDED', 'ACTIVE', 'PAST_DUE'].contains(state);
  bool get hasPendingChange => pendingRequests.any(
    (item) => item.kind == 'PLAN_CHANGE' || item.kind == 'RENEWAL',
  );
  bool get renewalPending =>
      pendingRequests.any((item) => item.kind == 'RENEWAL');

  /// "Pagar agora" is offered from 7 days before the date (E2).
  bool renewalDue(DateTime now) =>
      renewalQuote != null &&
      (pastDue ||
          (renewsAt != null &&
              !renewsAt!.isAfter(now.add(const Duration(days: 7)))));
  List<BillingTenant> get covered =>
      tenants.where((item) => item.covered).toList();

  String get stateLabel => switch (state) {
    'TRIAL' => 'Teste grátis',
    'TRIAL_ENDED' => 'Teste encerrado',
    'FREE' => 'Grátis',
    'ACTIVE' => 'Ativa',
    'PAST_DUE' => 'Vencida',
    _ => 'Não informada',
  };
}

/// Renewal of the paid plan (E2): the monthly value for 30 more days.
class RenewalQuote {
  const RenewalQuote({required this.amountCents, required this.days});
  factory RenewalQuote.fromJson(Map<String, dynamic> value) => RenewalQuote(
    amountCents: (value['amountCents'] as num?)?.toInt() ?? 0,
    days: (value['days'] as num?)?.toInt() ?? 30,
  );
  final int amountCents;
  final int days;
}

/// Payment inside the app (P2/P3). Off until the provider exists: the
/// screens show the methods as coming soon and charge nothing.
class OnlinePayments {
  const OnlinePayments({
    this.enabled = false,
    this.methods = const ['PIX', 'CARD', 'BOLETO'],
  });
  factory OnlinePayments.fromJson(Object? raw) => raw is Map
      ? OnlinePayments(
          enabled: raw['enabled'] == true,
          methods: [
            for (final item in (raw['methods'] as List?) ?? const [])
              if (item is String) item,
          ],
        )
      : const OnlinePayments();
  final bool enabled;
  final List<String> methods;

  static String label(String method) => switch (method) {
    'PIX' => 'Pix',
    'CARD' => 'Cartão de crédito',
    'BOLETO' => 'Boleto',
    _ => method,
  };
}

/// Data of a petshop exported as CSV files (E2): a copy for the principal
/// manager; nothing changes on the platform.
class TenantExport {
  const TenantExport({
    required this.tenantName,
    required this.files,
    required this.customers,
    required this.pets,
    required this.appointments,
  });
  factory TenantExport.fromJson(Map<String, dynamic> value) {
    final counts = Map<String, dynamic>.from(
      (value['counts'] as Map?) ?? const {},
    );
    return TenantExport(
      tenantName: value['tenantName'] as String? ?? '',
      files: [
        for (final item in (value['files'] as List?) ?? const [])
          ExportFile(
            name: (item as Map)['name'] as String,
            content: item['content'] as String? ?? '',
          ),
      ],
      customers: (counts['customers'] as num?)?.toInt() ?? 0,
      pets: (counts['pets'] as num?)?.toInt() ?? 0,
      appointments: (counts['appointments'] as num?)?.toInt() ?? 0,
    );
  }
  final String tenantName;
  final List<ExportFile> files;
  final int customers;
  final int pets;
  final int appointments;
}

class ExportFile {
  const ExportFile({required this.name, required this.content});
  final String name;
  final String content;

  /// UTF-8 with the byte order mark, so spreadsheets read the accents.
  List<int> get bytes => [0xEF, 0xBB, 0xBF, ...utf8.encode(content)];
}

class BillingTenant {
  const BillingTenant({
    required this.id,
    required this.name,
    required this.covered,
    required this.users,
    required this.professionals,
    this.maxUsers,
    this.action,
    this.phase,
  });
  factory BillingTenant.fromJson(Map<String, dynamic> value) {
    final usage = Map<String, dynamic>.from(
      (value['usage'] as Map?) ?? const {},
    );
    return BillingTenant(
      id: value['id'] as String,
      name: value['name'] as String? ?? '',
      covered: value['covered'] == true,
      users: (usage['users'] as num?)?.toInt() ?? 0,
      professionals: (usage['professionals'] as num?)?.toInt() ?? 0,
      maxUsers: (value['maxUsers'] as num?)?.toInt(),
      action: value['action'] as String?,
      phase: value['phase'] as String?,
    );
  }
  final String id;
  final String name;

  /// False while the petshop waits for a paid plan.
  final bool covered;
  final int users;
  final int professionals;
  final int? maxUsers;

  /// REMOVE or ADD when the petshop can leave or come back to the paid
  /// cycle now (A1-i); the server decides.
  final String? action;

  /// After the date of the cycle (E2): BOOKINGS_PAUSED or BLOCKED.
  final String? phase;
}

/// Extra petshop in the middle of the cycle (A1-i): the monthly fee for the
/// remaining days, refunded when it leaves and charged when it comes back.
class TenantQuote {
  const TenantQuote({
    required this.days,
    required this.monthlyCents,
    required this.removeCents,
    required this.addCents,
  });
  factory TenantQuote.fromJson(Map<String, dynamic> value) => TenantQuote(
    days: (value['days'] as num?)?.toInt() ?? 0,
    monthlyCents: (value['monthlyCents'] as num?)?.toInt() ?? 0,
    removeCents: (value['removeCents'] as num?)?.toInt() ?? 0,
    addCents: (value['addCents'] as num?)?.toInt() ?? 0,
  );
  final int days;
  final int monthlyCents;
  final int removeCents;
  final int addCents;
}

class BillingPlanOption {
  const BillingPlanOption({
    required this.id,
    required this.name,
    required this.description,
    required this.monthlyPriceCents,
    required this.extraTenantPriceCents,
    required this.free,
    required this.current,
    required this.tutorApp,
    required this.transport,
    this.maxUsers,
    this.maxTenants,
    this.quote,
    this.blockedReason,
  });
  factory BillingPlanOption.fromJson(Map<String, dynamic> value) {
    final features = Map<String, dynamic>.from(
      (value['features'] as Map?) ?? const {},
    );
    return BillingPlanOption(
      id: value['id'] as String,
      name: value['name'] as String? ?? '',
      description: value['description'] as String? ?? '',
      monthlyPriceCents: (value['monthlyPriceCents'] as num?)?.toInt() ?? 0,
      extraTenantPriceCents:
          (value['extraTenantPriceCents'] as num?)?.toInt() ?? 0,
      maxUsers: (value['maxUsers'] as num?)?.toInt(),
      maxTenants: (value['maxTenants'] as num?)?.toInt(),
      free: value['free'] == true,
      current: value['current'] == true,
      tutorApp: features['tutorApp'] != false,
      transport: features['transport'] != false,
      quote: value['quote'] is Map
          ? BillingQuote.fromJson(
              Map<String, dynamic>.from(value['quote'] as Map),
            )
          : null,
      blockedReason: value['blockedReason'] as String?,
    );
  }
  final String id;
  final String name;
  final String description;
  final int monthlyPriceCents;
  final int extraTenantPriceCents;
  final int? maxUsers;
  final int? maxTenants;
  final bool free;
  final bool current;
  final bool tutorApp;
  final bool transport;

  /// Value of moving to this plan now; null for the free plan and for the
  /// paid plan already in use.
  final BillingQuote? quote;

  /// Why the petshops do not fit in this plan today.
  final String? blockedReason;
}

/// Proportional value of a change or of a cancellation (30-day cycle).
class BillingQuote {
  const BillingQuote({
    required this.kind,
    required this.direction,
    required this.days,
    required this.amountCents,
    required this.nextCycleCents,
    this.withdrawal = false,
  });
  factory BillingQuote.fromJson(Map<String, dynamic> value) => BillingQuote(
    kind: value['kind'] as String? ?? '',
    direction: value['direction'] as String? ?? 'REFUND',
    days: (value['days'] as num?)?.toInt() ?? 0,
    amountCents: (value['amountCents'] as num?)?.toInt() ?? 0,
    nextCycleCents: (value['nextCycleCents'] as num?)?.toInt() ?? 0,
    withdrawal: value['withdrawal'] == true,
  );

  /// START, UPGRADE or DOWNGRADE.
  final String kind;

  /// CHARGE or REFUND.
  final String direction;
  final int days;
  final int amountCents;
  final int nextCycleCents;

  /// Full refund within 7 days of the first payment.
  final bool withdrawal;
}

class BillingRequestInfo {
  const BillingRequestInfo({
    required this.id,
    required this.kind,
    required this.amountCents,
    required this.direction,
    this.toPlanName,
    this.createdAt,
  });
  factory BillingRequestInfo.fromJson(Map<String, dynamic> value) =>
      BillingRequestInfo(
        id: value['id'] as String,
        kind: value['kind'] as String? ?? '',
        amountCents: (value['amountCents'] as num?)?.toInt() ?? 0,
        direction: value['direction'] as String? ?? 'CHARGE',
        toPlanName: value['toPlanName'] as String?,
        createdAt: _date(value['createdAt']),
      );
  final String id;

  /// PLAN_CHANGE, CHARGE, REFUND or RENEWAL.
  final String kind;
  final int amountCents;
  final String direction;
  final String? toPlanName;
  final DateTime? createdAt;

  String get label => switch (kind) {
    'PLAN_CHANGE' => 'Troca para o ${toPlanName ?? 'novo plano'}',
    'CHARGE' => 'Cobrança do petshop extra',
    'REFUND' => 'Devolução',
    'RENEWAL' => 'Renovação a confirmar',
    _ => 'Pedido',
  };
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;

/// Cents as Brazilian money, without the floating point of `money`.
String cents(int value) {
  final whole = (value.abs() ~/ 100).toString();
  final buffer = StringBuffer();
  for (var index = 0; index < whole.length; index++) {
    if (index > 0 && (whole.length - index) % 3 == 0) buffer.write('.');
    buffer.write(whole[index]);
  }
  return '${value < 0 ? '-' : ''}R\$ $buffer,${(value.abs() % 100).toString().padLeft(2, '0')}';
}
