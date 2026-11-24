import '../../core/formatters.dart';
import 'package:flutter/material.dart';
import '../../core/widgets.dart';
import '../../state/app_scope.dart';
import '../../domain/models.dart';
import 'support_requests_screen.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});
  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  String? _tenantId;
  final _reason = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    if (controller.admin == null) return const SizedBox.shrink();
    final result = controller.diagnostic;
    return Scaffold(
      appBar: AppBar(title: const Text('Suporte e diagnóstico')),
      body: PageBody(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (controller.supportDeskAvailable) ...[
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.forum_outlined),
                    title: const Text('Pedidos de suporte dos petshops'),
                    subtitle: const Text(
                      'Mensagens enviadas pelos gestores no aplicativo Equipe.',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SupportRequestsScreen(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              DropdownButtonFormField<String>(
                initialValue: _tenantId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Empresa'),
                items: controller.tenants
                    .map(
                      (t) => DropdownMenuItem(
                        value: t.id,
                        child: Text(tenantIdentification(t)),
                      ),
                    )
                    .toList(),
                validator: (v) => v == null ? 'Selecione a empresa' : null,
                onChanged: controller.busy
                    ? null
                    : (v) => setState(() => _tenantId = v),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _reason,
                maxLength: 1000,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Motivo do diagnóstico',
                ),
                validator: (v) =>
                    (v?.trim().length ?? 0) < 3 ? 'Informe o motivo' : null,
              ),
              const Text(
                'A consulta não altera os cadastros. O motivo e o administrador ficam registrados na auditoria.',
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: controller.busy || controller.readOnly
                    ? null
                    : () async {
                        if (_form.currentState!.validate()) {
                          await controller.diagnose(
                            _tenantId!,
                            _reason.text.trim(),
                          );
                        }
                      },
                child: const Text('Consultar diagnóstico'),
              ),
              if (controller.error != null) Text(controller.error!),
              if (result != null && result.tenantId == _tenantId) ...[
                const SizedBox(height: 20),
                Text(
                  'Empresa: ${TenantStatus.values.where((s) => s.name.toUpperCase() == result.tenantStatus).firstOrNull?.label ?? 'não informada'} · Assinatura: ${SubscriptionStatus.values.where((s) => s.name.toUpperCase() == result.subscriptionStatus).firstOrNull?.label ?? 'ausente'}',
                ),
                for (final step in result.onboarding)
                  Card(
                    child: ListTile(
                      leading: Icon(
                        step.completed
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                      ),
                      title: Text(step.label),
                      subtitle: Text(step.completed ? 'Concluído' : 'Pendente'),
                    ),
                  ),
                Text('Verificação: ${result.checkedAt}'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
