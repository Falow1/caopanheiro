import 'management_permissions.dart';
import 'package:caopanheiro_contracts/caopanheiro_contracts.dart'
    show TenantRole;

class InternalUser {
  const InternalUser({
    required this.name,
    this.phone = '',
    required this.role,
    this.roles = const [],
    this.managementDelegated = false,
    this.managementPermissions,
    this.canManageServices = false,
    this.canManageBlocks = false,
    this.canRunService = false,
  });
  final String name;

  /// The phone of the person, as they keep it in their profile.
  final String phone;
  final TenantRole role;
  final List<TenantRole> roles;
  final bool managementDelegated;
  final List<String>? managementPermissions;
  bool get isPrincipal =>
      !managementDelegated && (isManager || roles.contains(TenantRole.manager));
  bool canManage(String permission) =>
      !managementDelegated ||
      (managementPermissions ?? managementPermissionLabels.keys.toList())
          .contains(permission);
  bool get canManagePeople => isManager && !managementDelegated;
  List<TenantRole> get availableRoles =>
      (roles.isEmpty ? [role] : roles).contains(TenantRole.manager)
      ? [
          TenantRole.manager,
          TenantRole.attendant,
          if (canManage('APPOINTMENTS')) TenantRole.professional,
          if (canManage('TRANSPORT')) TenantRole.driver,
        ]
      : roles.isEmpty
      ? [role]
      : roles;
  bool get hasTeamOperations => availableRoles.any(
    (r) => r == TenantRole.manager || r == TenantRole.attendant,
  );
  InternalUser asFunction(TenantRole value) {
    if (!availableRoles.contains(value)) return this;
    return InternalUser(
      name: name,
      phone: phone,
      role: value,
      roles: availableRoles,
      managementDelegated: managementDelegated,
      managementPermissions: managementPermissions,
      canManageBlocks:
          (value == TenantRole.manager || value == TenantRole.attendant) &&
          canManage('APPOINTMENTS'),
      canManageServices: value == TenantRole.manager && canManage('SERVICES'),
      canRunService: value == TenantRole.manager && canManage('APPOINTMENTS'),
    );
  }

  /// The same access with the name and phone the person saved.
  InternalUser withContact(String name, String phone) => InternalUser(
    name: name,
    phone: phone,
    role: role,
    roles: roles,
    managementDelegated: managementDelegated,
    managementPermissions: managementPermissions,
    canManageServices: canManageServices,
    canManageBlocks: canManageBlocks,
    canRunService: canRunService,
  );

  final bool canManageServices;
  final bool canManageBlocks;
  final bool canRunService;
  bool get isManager => role == TenantRole.manager;
  String get roleLabel => role.label;
}
