import 'package:caopanheiro_contracts/caopanheiro_contracts.dart'
    show TenantRole;

class TenantUser {
  const TenantUser({
    required this.id,
    this.recordNumber,
    required this.name,
    required this.email,
    required this.role,
    required this.createdAt,
    this.active = true,
    this.activationPending = false,
    this.principal = false,
    this.deletionPending = false,
    this.lastAccess,
  });
  final int? recordNumber;
  final String id;
  final String name;
  final String email;
  final TenantRole role;
  final DateTime createdAt;
  final bool active;
  final bool activationPending;

  /// Principal manager of the petshop: only the SaaS can delete this account.
  final bool principal;

  /// Account deletion by the SaaS whose access removal is still pending.
  final bool deletionPending;
  String get statusLabel => deletionPending
      ? 'Exclusão pendente'
      : activationPending
      ? 'Ativação pendente'
      : active
      ? 'Ativo'
      : 'Inativo';
  final DateTime? lastAccess;
  TenantUser copyWith({bool? active}) => TenantUser(
    id: id,
    recordNumber: recordNumber,
    name: name,
    email: email,
    role: role,
    createdAt: createdAt,
    active: active ?? this.active,
    activationPending: activationPending,
    principal: principal,
    deletionPending: deletionPending,
    lastAccess: lastAccess,
  );
}
