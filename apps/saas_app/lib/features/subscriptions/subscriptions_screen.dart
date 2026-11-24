import 'package:caopanheiro_core/caopanheiro_core.dart' show recordCaption;
import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';
import '../../state/app_scope.dart';
import '../plans/plans_screen.dart';
import 'billing_requests_screen.dart';
import 'subscription_detail_screen.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});
  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  SubscriptionStatus? _filter;
  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    if (controller.admin == null) return const SizedBox.shrink();
    final items = controller.subscriptions
        .where((item) => _filter == null || item.status == _filter)
        .toList();
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
              child: SaasPageTitle(
                'Assinaturas',
                subtitle: 'Situação comercial dos Tenants',
                action: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PlansScreen()),
                  ),
                  child: const Text('Planos'),
                ),
              ),
            ),
            if (controller.billingQueue.subscriptionCount > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.hourglass_top_rounded),
                    title: Text(
                      controller.billingQueue.subscriptionCount == 1
                          ? '1 pedido aguardando a plataforma'
                          : '${controller.billingQueue.subscriptionCount} pedidos aguardando a plataforma',
                    ),
                    subtitle: const Text(
                      'Trocas de plano, pagamentos e devoluções dos gestores',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BillingRequestsScreen(),
                      ),
                    ),
                  ),
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
                    selected: _filter == SubscriptionStatus.active,
                    onTap: () =>
                        setState(() => _filter = SubscriptionStatus.active),
                  ),
                  _Filter(
                    label: 'Trial',
                    selected: _filter == SubscriptionStatus.trial,
                    onTap: () =>
                        setState(() => _filter = SubscriptionStatus.trial),
                  ),
                  _Filter(
                    label: 'Pendentes',
                    selected: _filter == SubscriptionStatus.pending,
                    onTap: () =>
                        setState(() => _filter = SubscriptionStatus.pending),
                  ),
                  _Filter(
                    label: 'Canceladas',
                    selected: _filter == SubscriptionStatus.cancelled,
                    onTap: () =>
                        setState(() => _filter = SubscriptionStatus.cancelled),
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
                  final item = items[index];
                  final tenant = controller.tenantById(item.tenantId);
                  final plan = controller.planById(item.planId);
                  return Card(
                    child: ListTile(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              SubscriptionDetailScreen(tenantId: tenant.id),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 17,
                        vertical: 10,
                      ),
                      title: Text(
                        tenantIdentification(tenant),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      subtitle: Text(
                        recordCaption(
                          item.renewsAt == null
                              ? plan.name
                              : '${plan.name} · Renovação: ${date(item.renewsAt!)}',
                          'Assinatura',
                          item.recordNumber,
                        ),
                      ),
                      trailing: SubscriptionBadge(status: item.status),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
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
