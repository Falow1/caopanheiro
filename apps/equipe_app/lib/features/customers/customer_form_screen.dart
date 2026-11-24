import 'package:caopanheiro_core/caopanheiro_core.dart';
import 'package:flutter/material.dart';

import '../../core/widgets.dart';
import '../../domain/models.dart';
import '../../state/app_scope.dart';

class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({super.key, this.customer});
  final Customer? customer;
  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  late final _customerId = widget.customer?.id ?? newRecordId();
  final _key = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.customer?.name);
  late final _phone = TextEditingController(
    text: displayPhone(widget.customer?.phone ?? ''),
  );
  late final _email = TextEditingController(text: widget.customer?.email);

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Preencha este campo' : null;

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    final value = Customer(
      id: _customerId,
      name: _name.text.trim(),
      phone: formatBrazilPhone(_phone.text) ?? _phone.text.trim(),
      email: _email.text.trim(),
      pets: widget.customer?.pets ?? const [],
      tutorUid: widget.customer?.tutorUid,
    );
    if (await AppScope.of(context).saveCustomer(value) && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => FormScaffold(
    title: widget.customer == null ? 'Novo cliente' : 'Editar tutor',
    child: AppScope.of(context).catalogOffline
        ? const PermissionNotice(
            message:
                'Conecte-se e atualize os dados para cadastrar ou editar clientes.',
          )
        : Form(
            key: _key,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _name,
                  validator: _required,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                const SizedBox(height: 14),
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
                const SizedBox(height: 14),
                TextFormField(
                  controller: _email,
                  validator: _required,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'E-mail'),
                ),
                const SizedBox(height: 24),
                if (AppScope.of(context).error != null)
                  Text(AppScope.of(context).error!),
                FilledButton(
                  onPressed: AppScope.of(context).busy ? null : _save,
                  child: const Text('Salvar'),
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
