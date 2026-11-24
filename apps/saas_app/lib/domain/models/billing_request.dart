/// Request of the manager subscription waiting for the platform (A1-r): a
/// plan change to confirm and apply, a charge of an extra petshop or a refund
/// made outside the app, before the payment provider (P2).
class BillingRequest {
  const BillingRequest({
    required this.id,
    required this.kind,
    required this.ownerName,
    required this.amountCents,
    required this.direction,
    required this.tenantNames,
    this.fromPlanName,
    this.toPlanName,
    this.days,
    this.reason,
    this.createdAt,
  });

  /// PLAN_CHANGE, CHARGE, REFUND or RENEWAL (E2: 30 more days, paid outside
  /// the app, to confirm).
  final String kind;
  final String id;
  final String ownerName;
  final int amountCents;

  /// CHARGE or REFUND.
  final String direction;
  final List<String> tenantNames;
  final String? fromPlanName;
  final String? toPlanName;
  final int? days;

  /// EXTRA_TENANT, EXTRA_TENANT_REMOVED, PLAN_DOWNGRADE, CANCEL_NOW or
  /// WITHDRAWAL.
  final String? reason;
  final DateTime? createdAt;

  String get title => switch (kind) {
    'PLAN_CHANGE' => 'Troca de plano',
    'CHARGE' => 'Pagamento a confirmar',
    'REFUND' => 'Devolução a registrar',
    'RENEWAL' => 'Renovação a confirmar',
    _ => 'Pedido',
  };

  String get detail => switch ((kind, reason)) {
    ('PLAN_CHANGE', _) => '${fromPlanName ?? '-'} → ${toPlanName ?? '-'}',
    ('RENEWAL', _) => 'Mais ${days ?? 30} dias do ${toPlanName ?? 'plano'}',
    ('CHARGE', 'EXTRA_TENANT') => 'Petshop extra no ${toPlanName ?? 'plano'}',
    ('REFUND', 'PLAN_DOWNGRADE') =>
      'Troca para o ${toPlanName ?? 'plano menor'}',
    ('REFUND', 'WITHDRAWAL') => 'Arrependimento em até 7 dias',
    ('REFUND', 'CANCEL_NOW') => 'Cancelamento imediato',
    ('REFUND', 'EXTRA_TENANT_REMOVED') =>
      'Petshop extra retirado do ${fromPlanName ?? 'plano'}',
    _ => toPlanName ?? fromPlanName ?? '',
  };
}

/// Pending items of the platform (A1-s): subscription requests and support
/// requests waiting for an answer.
class BillingQueue {
  const BillingQueue({
    this.items = const [],
    this.planChanges = 0,
    this.charges = 0,
    this.refunds = 0,
    this.renewals = 0,
    this.supportWaiting = 0,
    this.supportCapped = false,
  });
  final List<BillingRequest> items;
  final int planChanges;
  final int charges;
  final int refunds;

  /// Renewals paid outside the app, waiting for the platform (E2).
  final int renewals;
  final int supportWaiting;

  /// More support requests than the server counts at once.
  final bool supportCapped;

  /// Requests of the Assinaturas tab.
  int get subscriptionCount => planChanges + charges + refunds + renewals;
  int get total => subscriptionCount + supportWaiting;
}
