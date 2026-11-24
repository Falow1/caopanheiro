import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppEmptyLabel, AppRadii;

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../core/widgets.dart';
import '../../state/app_scope.dart';
import 'audit_detail_screen.dart';

class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key, this.tenantId});
  final String? tenantId;
  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  String? _entity;
  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    if (controller.admin == null) return const SizedBox.shrink();
    final events = controller.auditEvents
        .where(
          (event) =>
              (widget.tenantId == null || event.tenantId == widget.tenantId) &&
              (_entity == null || event.entity == _entity),
        )
        .toList();
    return Scaffold(
      appBar: widget.tenantId == null
          ? null
          : AppBar(title: const Text('Histórico do Tenant')),
      body: SafeArea(
        top: widget.tenantId == null,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.tenantId == null) const SaasPageTitle('Auditoria'),
                  if (widget.tenantId == null) const SizedBox(height: 14),
                  DropdownButtonFormField<String?>(
                    initialValue: _entity,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de evento',
                    ),
                    items: const [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Todos'),
                      ),
                      DropdownMenuItem(value: 'Tenant', child: Text('Tenant')),
                      DropdownMenuItem(
                        value: 'Usuário',
                        child: Text('Usuário'),
                      ),
                      DropdownMenuItem(
                        value: 'Assinatura',
                        child: Text('Assinatura'),
                      ),
                      DropdownMenuItem(value: 'Plano', child: Text('Plano')),
                    ],
                    onChanged: (value) => setState(() => _entity = value),
                  ),
                ],
              ),
            ),
            Expanded(
              child: events.isEmpty
                  ? const AppEmptyLabel('Nenhum evento encontrado.')
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 90),
                      itemCount: events.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 9),
                      itemBuilder: (_, index) {
                        final event = events[index];
                        final tenant = event.tenantId == null
                            ? null
                            : controller.tenantById(event.tenantId!);
                        return Card(
                          child: ListTile(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    AuditDetailScreen(eventId: event.id),
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: AppColors.mint,
                                borderRadius: AppRadii.r13,
                              ),
                              child: Center(
                                child: Text(
                                  time(event.createdAt),
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              event.action,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            subtitle: Text(
                              '${tenant == null ? event.entity : tenantIdentification(tenant)} · ${event.fromTenant ? 'pela equipe do petshop: ' : 'por '}${event.admin}',
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
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
