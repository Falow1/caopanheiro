import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppRadii, AppTextStyles, showAppConfirmation;

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../state/app_scope.dart';

class ChangePlanScreen extends StatefulWidget {
  const ChangePlanScreen({super.key, required this.subscriptionId});
  final String subscriptionId;
  @override
  State<ChangePlanScreen> createState() => _ChangePlanScreenState();
}

class _ChangePlanScreenState extends State<ChangePlanScreen> {
  String? _selected;
  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    if (controller.admin == null) return const SizedBox.shrink();
    final subscription = controller.subscriptions.firstWhere(
      (item) => item.id == widget.subscriptionId,
    );
    _selected ??= subscription.planId;
    return Scaffold(
      appBar: AppBar(title: const Text('Alterar plano')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        children: [
          Text(
            'Escolha o novo plano',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 18),
          ...controller.plans.where((plan) => plan.active).map((plan) {
            final selected = _selected == plan.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: Card(
                color: selected ? AppColors.mint : AppColors.paper,
                child: InkWell(
                  onTap: () => setState(() => _selected = plan.id),
                  borderRadius: AppRadii.r20,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          margin: const EdgeInsets.only(right: 14, top: 2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected
                                ? AppColors.primary
                                : Colors.transparent,
                            border: Border.all(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.muted,
                              width: 2,
                            ),
                          ),
                          child: selected
                              ? const Icon(
                                  Icons.check_rounded,
                                  size: 16,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                plan.name,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              Text('${money(plan.monthlyPrice)}/mês'),
                              const SizedBox(height: 8),
                              Text(
                                'Até ${plan.maxProfessionals} profissionais · ${plan.features.join(', ')}',
                                style: AppTextStyles.caption,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _selected == subscription.planId || controller.busy
                ? null
                : () => _confirm(subscription.id),
            child: const Text('Confirmar alteração'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirm(String id) async {
    final controller = AppScope.of(context);
    final plan = controller.planById(_selected!);
    final confirmed = await showAppConfirmation(
      context,
      title: 'Confirmar alteração?',
      message:
          'O plano será alterado para ${plan.name}. A situação da assinatura e a suspensão da empresa serão mantidas.',
      confirmLabel: 'Confirmar',
    );
    if (!mounted) return;
    if (confirmed) {
      final success = await controller.updateSubscription(
        id,
        plan.id,
        controller.subscriptions.firstWhere((item) => item.id == id).status,
      );
      if (mounted && success) {
        Navigator.pop(context);
      }
    }
  }
}
