import '../../core/team_layout.dart';
import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppScreenTips, AppTourTarget;
import '../../core/screen_tips.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppNoticeBanner, AppTextStyles;

import '../../core/app_theme.dart';
import '../../domain/models.dart';
import '../../state/app_scope.dart';
import 'customer_detail_screen.dart';
import 'customer_form_screen.dart';
import 'tutor_join_link_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});
  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  String _query = '';
  @override
  Widget build(BuildContext context) => AppScreenTips(
    screen: TipScreens.customers,
    tips: TeamTips.customers,
    ready: !AppScope.of(context).busy,
    child: _content(context),
  );

  Widget _content(BuildContext context) {
    final controller = AppScope.of(context);
    if (controller.user == null) return const SizedBox.shrink();
    final customers = AppScope.of(context).customers.where((item) {
      final value = _query.toLowerCase();
      return item.name.toLowerCase().contains(value) ||
          item.phone.contains(value);
    }).toList();
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: TeamLayout.header,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Clientes',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  if (controller.catalogOnly) ...[
                    Text(controller.company?.name ?? ''),
                    if (controller.localWarning != null)
                      Text(controller.localWarning!),
                    if (controller.customersError != null)
                      Text(controller.customersError!),
                    if (controller.busy) const LinearProgressIndicator(),
                    if (!controller.customersLoaded && !controller.busy)
                      const Text(
                        'Puxe para baixo para consultar os clientes desta empresa.',
                      ),
                    if (controller.pendingTutorReturns > 0) ...[
                      const SizedBox(height: 8),
                      AppNoticeBanner(
                        background: AppColors.noticeSurface,
                        icon: Icons.person_add_alt_outlined,
                        iconColor: AppColors.primary,
                        title: controller.pendingTutorReturns == 1
                            ? '1 tutor pede para voltar'
                            : '${controller.pendingTutorReturns} tutores pedem para voltar',
                        message:
                            'Foram desvinculados por este petshop e abriram o link de convite.',
                        action: TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TutorJoinLinkScreen(),
                            ),
                          ),
                          child: const Text('Ver'),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                  AppTourTarget(
                    id: TipTargets.customersSearch,
                    child: TextField(
                      onChanged: (value) => setState(() => _query = value),
                      decoration: const InputDecoration(
                        hintText: 'Buscar por número, nome ou telefone',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: TeamLayout.list,
                itemCount: customers.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, index) => AppTourTarget(
                  id: TipTargets.customersCard,
                  child: _CustomerTile(
                    customer: customers[index],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CustomerDetailScreen(
                          customerId: customers[index].id,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton:
          controller.catalogOffline ||
              controller.user?.canManage('CUSTOMERS') != true
          ? null
          : AppTourTarget(
              id: TipTargets.customersNew,
              child: FloatingActionButton.extended(
                heroTag: 'team-new-customer',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CustomerFormScreen()),
                ),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Novo cliente'),
              ),
            ),
    );
  }
}

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({required this.customer, required this.onTap});
  final Customer customer;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: AppColors.mint,
        child: Text(
          customer.name.substring(0, 1),
          style: AppTextStyles.primaryStrong,
        ),
      ),
      title: Text(
        customer.name,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Text(
        '${customer.phone} · ${customer.pets.length}${customer.pets.length == 1 ? ' pet' : ' pets'}',
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
    ),
  );
}
