import '../../../core/formatters.dart';
import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppRadii;

import '../../../domain/models.dart';
import '../../../core/app_theme.dart';

class ContextHeader extends StatelessWidget {
  const ContextHeader({
    super.key,
    required this.tenant,
    required this.planName,
  });
  final Tenant tenant;
  final String planName;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: AppColors.navy,
      borderRadius: AppRadii.r19,
    ),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .12),
            borderRadius: AppRadii.r13,
          ),
          child: const Icon(Icons.storefront_rounded, color: Colors.white),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tenantIdentification(tenant),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: Colors.white),
              ),
              Text(
                'Tenant ${tenant.status.label.toLowerCase()} · $planName',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
