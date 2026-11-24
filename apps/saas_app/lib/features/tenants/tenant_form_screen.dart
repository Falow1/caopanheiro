import 'package:caopanheiro_core/caopanheiro_core.dart';
import 'package:flutter/material.dart';

import '../../core/widgets.dart';
import '../../domain/models.dart';
import 'application/tenant_form_operations.dart';
import '../../state/app_scope.dart';
import '../onboarding/manager_form_screen.dart';

class TenantFormScreen extends StatefulWidget {
  const TenantFormScreen({super.key, this.tenantId});
  final String? tenantId;
  @override
  State<TenantFormScreen> createState() => _TenantFormScreenState();
}

class _TenantFormScreenState extends State<TenantFormScreen> {
  final _newId = newRecordId();
  final _key = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _tradeName = TextEditingController();
  final _document = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController(text: 'MT');
  final _slug = TextEditingController();
  String? _planId;
  TenantStatus _status = TenantStatus.onboarding;
  Tenant? _original;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.tenantId != null && _original == null) {
      _original = AppScope.of(context).tenantById(widget.tenantId!);
      _name.text = _original!.name;
      _tradeName.text = _original!.tradeName;
      _document.text = _original!.document;
      _phone.text = displayPhone(_original!.phone);
      _email.text = _original!.email;
      _city.text = _original!.city;
      _state.text = _original!.state;
      _slug.text = _original!.slug;
      _planId = _original!.planId;
      _status = _original!.status;
    }
    _planId ??= AppScope.of(
      context,
    ).plans.where((plan) => plan.active).firstOrNull?.id;
  }

  @override
  void dispose() {
    _name.dispose();
    _tradeName.dispose();
    _document.dispose();
    _phone.dispose();
    _email.dispose();
    _city.dispose();
    _state.dispose();
    _slug.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Preencha este campo' : null;

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    if (_planId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cadastre um plano ativo primeiro.')),
      );
      return;
    }
    final isNew = _original == null;
    final tenant = createTenantFromForm(
      original: _original,
      newId: _newId,
      name: _name.text,
      tradeName: _tradeName.text,
      slug: _slug.text,
      document: _document.text,
      phone: formatBrazilPhone(_phone.text) ?? _phone.text,
      email: _email.text,
      city: _city.text,
      state: _state.text,
      status: _status,
      planId: _planId,
    );
    if (await AppScope.of(context).saveTenant(tenant) && mounted) {
      if (isNew && AppScope.of(context).refreshWarning == null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ManagerFormScreen(tenantId: tenant.id),
          ),
        );
      } else {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    if (controller.admin == null) return const SizedBox.shrink();
    return FormPage(
      title: _original == null ? 'Cadastrar empresa' : 'Editar empresa',
      child: Form(
        key: _key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_original != null) ...[
              Text('Tenant ID', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 5),
              SelectableText(_original!.id),
              const SizedBox(height: 18),
            ],
            TextFormField(
              controller: _name,
              validator: _required,
              decoration: const InputDecoration(labelText: 'Razão social'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tradeName,
              validator: _required,
              decoration: const InputDecoration(labelText: 'Nome fantasia'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _document,
              validator: _required,
              decoration: const InputDecoration(labelText: 'Documento'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _phone,
                    validator: phoneValidator,
                    keyboardType: TextInputType.phone,
                    inputFormatters: const [PhoneInputFormatter()],
                    decoration: const InputDecoration(
                      labelText: 'Telefone',
                      hintText: phoneHint,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _email,
                    validator: _required,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'E-mail'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _city,
                    validator: _required,
                    decoration: const InputDecoration(labelText: 'Cidade'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _state,
                    validator: _required,
                    decoration: const InputDecoration(labelText: 'UF'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _slug,
              validator: _required,
              decoration: const InputDecoration(
                labelText: 'Slug',
                helperText:
                    'Identificador público; o tenantId é gerado pelo sistema.',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _planId,
              decoration: const InputDecoration(labelText: 'Plano inicial'),
              items: controller.plans
                  .where((item) => item.active || item.id == _original?.planId)
                  .map(
                    (plan) => DropdownMenuItem(
                      value: plan.id,
                      child: Text(plan.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _planId = value),
            ),
            const SizedBox(height: 12),
            if (!controller.integrated)
              DropdownButtonFormField<TenantStatus>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Situação'),
                items: TenantStatus.values
                    .map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(status.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _status = value!),
              ),
            if (controller.integrated && _original == null)
              const Text(
                'A nova empresa é criada ativa, com assinatura em trial de 14 dias. Não há cobrança automática nesta etapa.',
              ),
            if (controller.error != null) Text(controller.error!),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: controller.busy || controller.readOnly ? null : _save,
              child: Text(
                controller.busy
                    ? 'Salvando...'
                    : (_original == null
                          ? 'Criar empresa'
                          : 'Salvar alterações'),
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
