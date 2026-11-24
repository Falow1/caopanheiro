import 'package:equipe_app/domain/policies/transport_review.dart';
import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppActionCard, AppRadii;
import '../../../domain/models.dart';
import '../../../core/app_theme.dart';
import '../../../core/formatters.dart';
import 'transport_status_chip.dart';

class TransportCard extends StatelessWidget {
  const TransportCard({
    super.key,
    required this.transport,
    required this.onTap,
    this.showDate = false,
  });
  final TransportJob transport;
  final VoidCallback onTap;
  final bool showDate;

  @override
  Widget build(BuildContext context) => AppActionCard(
    onTap: onTap,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 60,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.mint,
            borderRadius: AppRadii.r15,
          ),
          child: Column(
            children: [
              if (showDate)
                Text(
                  '${transport.displayScheduledAt.day}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              Text(
                time(transport.displayScheduledAt),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                transport.type.label.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.orange,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .8,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                transport.petsLabel,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 3),
              Text(
                '${transport.origin.name} → ${transport.destination.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 9),
              TransportStatusChip(status: transport.status),
              if (transportNeedsReview(
                transport.scheduledAt,
                transport.status.name == 'assigned' ? 'ASSIGNED' : '',
              ))
                const Text('Atrasado — precisa de revisão'),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
      ],
    ),
  );
}
