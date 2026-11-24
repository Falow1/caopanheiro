import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppContentCard, AppRadii, AppTextStyles;

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../core/widgets.dart';
import '../../state/app_scope.dart';

class AuditDetailScreen extends StatelessWidget {
  const AuditDetailScreen({super.key, required this.eventId});
  final String eventId;
  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    if (controller.admin == null) return const SizedBox.shrink();
    final event = controller.auditEvents.firstWhere(
      (item) => item.id == eventId,
    );
    final tenant = event.tenantId == null
        ? null
        : controller.tenantById(event.tenantId!);
    final items = [
      ('Ação', event.action),
      (
        'Origem',
        event.fromTenant
            ? 'Equipe do petshop (aplicativo Equipe)'
            : 'Administração da plataforma',
      ),
      ('Executado por', event.admin),
      (
        'Empresa',
        tenant == null ? 'Não aplicável' : tenantIdentification(tenant),
      ),
      ('Data e horário', dateTime(event.createdAt)),
      ('Entidade', event.entity),
      ('Resultado', event.result),
      if (event.reason?.isNotEmpty == true) ('Motivo', event.reason!),
      if (event.details['beforeStatus'] != null)
        ('Situação anterior', '${event.details['beforeStatus']}'),
      if (event.details['afterStatus'] != null)
        ('Situação resultante', '${event.details['afterStatus']}'),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Detalhes do evento')),
      body: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: AppRadii.r20,
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_user_outlined, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Registro administrativo imutável',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            AppContentCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: items
                    .asMap()
                    .entries
                    .map(
                      (entry) => Padding(
                        padding: EdgeInsets.only(
                          bottom: entry.key == items.length - 1 ? 0 : 15,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 115,
                              child: Text(
                                entry.value.$1,
                                style: AppTextStyles.metadata,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                entry.value.$2,
                                style: AppTextStyles.value,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
