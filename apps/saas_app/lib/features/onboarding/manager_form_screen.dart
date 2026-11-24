import 'package:caopanheiro_core/caopanheiro_core.dart'
    show PhoneInputFormatter, phoneHint, phoneValidator;
import 'package:flutter/material.dart';

import '../../core/widgets.dart';
import '../../domain/models.dart';
import 'application/onboarding_operations.dart';
import '../../state/app_scope.dart';
import 'onboarding_screen.dart';

class ManagerFormScreen extends StatefulWidget {
  const ManagerFormScreen({super.key, required this.tenantId});
  final String tenantId;
  @override
  State<ManagerFormScreen> createState() => _ManagerFormScreenState();
}

class _ManagerFormScreenState extends State<ManagerFormScreen> {
  TenantRole _role = TenantRole.manager;
  final _key = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Preencha este campo' : null;
  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    final manager = createInitialManager(name: _name.text, email: _email.text);
    final controller = AppScope.of(context);
    final success = controller.integrated
        ? await controller.saveMember(
            widget.tenantId,
            _name.text.trim(),
            _email.text.trim(),
            _role.apiValue,
          )
        : await controller.saveInitialManager(widget.tenantId, manager);
    if (success && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OnboardingScreen(tenantId: widget.tenantId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    if (controller.admin == null) return const SizedBox.shrink();
    final tenant = controller.tenantById(widget.tenantId);
    return FormPage(
      title: controller.integrated
          ? 'Convidar ou vincular pessoa'
          : 'Criar Gestor inicial',
      child: Form(
        key: _key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ContextHeader(
              tenant: tenant,
              planName: controller.planById(tenant.planId).name,
            ),
            const SizedBox(height: 20),
            const Text(
              'Acesso à empresa',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              validator: _required,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              validator: _required,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-mail'),
            ),
            const SizedBox(height: 12),
            if (!controller.integrated)
              TextFormField(
                controller: _phone,
                validator: phoneValidator,
                keyboardType: TextInputType.phone,
                inputFormatters: const [PhoneInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Telefone',
                  hintText: phoneHint,
                ),
              ),
            const SizedBox(height: 12),
            if (!controller.integrated)
              TextFormField(
                controller: _password,
                validator: _required,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Senha temporária',
                ),
              ),
            if (controller.integrated) ...[
              Text(
                _role == TenantRole.manager
                    ? 'O gestor define a própria senha e confirma seus dados no Primeiro acesso do app Equipe. Conta existente conserva a senha. Convite válido por 24 horas e uso único. Nesta versão, a mensagem fica na caixa local managerInvitationOutbox; não há envio real de e-mail.'
                    : 'A pessoa precisa criar sua conta e verificar o e-mail. A vinculação não cria uma senha.',
              ),
              DropdownButtonFormField<TenantRole>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Papel'),
                items: TenantRole.values
                    .map(
                      (role) => DropdownMenuItem(
                        value: role,
                        child: Text(role.label),
                      ),
                    )
                    .toList(),
                onChanged: (role) => setState(() => _role = role!),
              ),
            ],
            if (controller.error != null) Text(controller.error!),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: controller.busy || controller.readOnly ? null : _save,
              child: Text(
                controller.integrated
                    ? (_role == TenantRole.manager
                          ? 'Convidar gestor'
                          : 'Vincular pessoa')
                    : 'Criar Gestor',
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}
