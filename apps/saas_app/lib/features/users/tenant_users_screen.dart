import 'package:caopanheiro_core/caopanheiro_core.dart' show recordCaption;
import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppEmptyLabel, AppTextStyles;

import '../../core/app_theme.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';
import '../../state/app_scope.dart';
import 'user_detail_screen.dart';
import '../onboarding/manager_form_screen.dart';

class TenantUsersScreen extends StatefulWidget {
  const TenantUsersScreen({super.key, required this.tenantId});
  final String tenantId;
  @override
  State<TenantUsersScreen> createState() => _TenantUsersScreenState();
}

class _TenantUsersScreenState extends State<TenantUsersScreen> {
  TenantRole? _role;
  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    if (controller.admin == null) return const SizedBox.shrink();
    final tenant = controller.tenantById(widget.tenantId);
    final plan = controller.planById(tenant.planId);
    final users = tenant.users
        .where((user) => _role == null || user.role == _role)
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuários da empresa'),
        actions: [
          if (controller.integrated)
            IconButton(
              tooltip: 'Vincular pessoa',
              onPressed: controller.readOnly || controller.busy
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ManagerFormScreen(tenantId: widget.tenantId),
                      ),
                    ),
              icon: const Icon(Icons.person_add_outlined),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
            child: ContextHeader(tenant: tenant, planName: plan.name),
          ),
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _Filter(
                  label: 'Todos',
                  selected: _role == null,
                  onTap: () => setState(() => _role = null),
                ),
                _Filter(
                  label: 'Gestores',
                  selected: _role == TenantRole.manager,
                  onTap: () => setState(() => _role = TenantRole.manager),
                ),
                _Filter(
                  label: 'Atendentes',
                  selected: _role == TenantRole.attendant,
                  onTap: () => setState(() => _role = TenantRole.attendant),
                ),
                _Filter(
                  label: 'Profissionais',
                  selected: _role == TenantRole.professional,
                  onTap: () => setState(() => _role = TenantRole.professional),
                ),
              ],
            ),
          ),
          Expanded(
            child: users.isEmpty
                ? const AppEmptyLabel('Nenhum usuário neste filtro.')
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
                    itemCount: users.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 9),
                    itemBuilder: (_, index) {
                      final user = users[index];
                      return Card(
                        child: ListTile(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UserDetailScreen(
                                tenantId: tenant.id,
                                userId: user.id,
                              ),
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: AppColors.mint,
                            child: Text(
                              user.name.substring(0, 1),
                              style: AppTextStyles.primaryStrong,
                            ),
                          ),
                          title: Text(
                            user.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          subtitle: Text(
                            recordCaption(
                              user.role.label,
                              'Usuário',
                              user.recordNumber,
                            ),
                          ),
                          trailing: Text(
                            user.statusLabel,
                            style: TextStyle(
                              color: user.active
                                  ? AppColors.primary
                                  : AppColors.danger,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _Filter extends StatelessWidget {
  const _Filter({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
    ),
  );
}
