import 'package:caopanheiro_core/caopanheiro_core.dart'
    show recordNumberMatches;
import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppRadii;

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';
import '../../state/app_scope.dart';
import 'tenant_detail_screen.dart';
import 'tenant_form_screen.dart';

class TenantsScreen extends StatefulWidget {
  const TenantsScreen({super.key});
  @override
  State<TenantsScreen> createState() => _TenantsScreenState();
}

class _TenantsScreenState extends State<TenantsScreen> {
  String _query = '';
  TenantStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    if (controller.admin == null) return const SizedBox.shrink();
    final items = controller.tenants.where((tenant) {
      final query = _query.trim().toLowerCase();
      final matches =
          tenant.name.toLowerCase().contains(query) ||
          tenant.tradeName.toLowerCase().contains(query) ||
          recordNumberMatches(tenant.recordNumber, query) ||
          tenant.responsible.toLowerCase().contains(query);
      return matches && (_filter == null || tenant.status == _filter);
    }).toList();
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SaasPageTitle(
                    'Empresas',
                    action: IconButton.filled(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TenantFormScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    onChanged: (value) => setState(() => _query = value),
                    decoration: const InputDecoration(
                      hintText: 'Buscar empresa, código ou responsável',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _Filter(
                    label: 'Todas',
                    selected: _filter == null,
                    onTap: () => setState(() => _filter = null),
                  ),
                  _Filter(
                    label: 'Ativas',
                    selected: _filter == TenantStatus.active,
                    onTap: () => setState(() => _filter = TenantStatus.active),
                  ),
                  _Filter(
                    label: 'Suspensas',
                    selected: _filter == TenantStatus.suspended,
                    onTap: () =>
                        setState(() => _filter = TenantStatus.suspended),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, index) {
                  final tenant = items[index];
                  final plan = controller.planById(tenant.planId);
                  return Card(
                    child: InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              TenantDetailScreen(tenantId: tenant.id),
                        ),
                      ),
                      borderRadius: AppRadii.r20,
                      child: Padding(
                        padding: const EdgeInsets.all(17),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    tenantIdentification(tenant),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ),
                                TenantBadge(status: tenant.status),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('Plano ${plan.name}'),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(
                                  Icons.group_outlined,
                                  size: 17,
                                  color: AppColors.muted,
                                ),
                                const SizedBox(width: 6),
                                Text('${tenant.users.length} usuários'),
                                const Spacer(),
                                Text(
                                  'Desde ${date(tenant.createdAt)}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TenantFormScreen()),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova empresa'),
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
