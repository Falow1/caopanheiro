import 'package:caopanheiro_core/caopanheiro_core.dart';
import 'package:flutter/material.dart';

import '../../core/widgets.dart';
import '../../domain/models.dart';
import '../../state/app_scope.dart';

class PlanFormScreen extends StatefulWidget {
  const PlanFormScreen({super.key, this.planId});
  final String? planId;
  @override
  State<PlanFormScreen> createState() => _PlanFormScreenState();
}

class _PlanFormScreenState extends State<PlanFormScreen> {
  final _newId = newRecordId();
  final _key = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _professionals = TextEditingController();
  final _users = TextEditingController();
  final _features = TextEditingController();
  Plan? _original;
  bool _active = true;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.planId != null && _original == null) {
      _original = AppScope.of(context).planById(widget.planId!);
      _name.text = _original!.name;
      _description.text = _original!.description;
      _price.text = _original!.monthlyPrice
          .toStringAsFixed(2)
          .replaceAll('.', ',');
      _professionals.text = '${_original!.maxProfessionals}';
      _users.text = '${_original!.maxUsers}';
      _features.text = _original!.features.join(', ');
      _active = _original!.active;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _professionals.dispose();
    _users.dispose();
    _features.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Preencha este campo' : null;
  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    final price = double.tryParse(_price.text.replaceAll(',', '.'));
    final professionals = int.tryParse(_professionals.text);
    final users = int.tryParse(_users.text);
    if (price == null ||
        !price.isFinite ||
        price < 0 ||
        professionals == null ||
        professionals < 1 ||
        users == null ||
        users < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Informe preço não negativo e limites inteiros positivos.',
          ),
        ),
      );
      return;
    }
    final plan = Plan(
      id: _original?.id ?? _newId,
      name: _name.text.trim(),
      description: _description.text.trim(),
      monthlyPrice: price,
      maxProfessionals: professionals,
      maxUsers: users,
      features: _features.text
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(),
      active: _active,
    );
    if (await AppScope.of(context).savePlan(plan) && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    if (controller.admin == null) return const SizedBox.shrink();
    return FormPage(
      title: _original == null ? 'Novo plano' : 'Editar plano',
      child: Form(
        key: _key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _name,
              validator: _required,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              validator: _required,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Descrição'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _price,
              validator: _required,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Preço mensal (R\$)',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _professionals,
                    validator: _required,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Máx. profissionais',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _users,
                    validator: _required,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Máx. usuários',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _features,
              validator: _required,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Funcionalidades',
                helperText: 'Separe os itens por vírgula.',
              ),
            ),
            SwitchListTile(
              value: _active,
              onChanged: (value) => setState(() => _active = value),
              contentPadding: EdgeInsets.zero,
              title: Text(_active ? 'Plano ativo' : 'Plano inativo'),
              subtitle: const Text(
                'Planos inativos não ficam disponíveis para novas contratações.',
              ),
            ),
            const SizedBox(height: 18),
            if (controller.error != null) Text(controller.error!),
            FilledButton(
              onPressed: controller.busy || controller.readOnly ? null : _save,
              child: const Text('Salvar plano'),
            ),
            if (_original != null)
              OutlinedButton(
                onPressed: controller.busy || controller.readOnly
                    ? null
                    : () {
                        setState(() => _active = !_active);
                        _save();
                      },
                child: Text(_active ? 'Desativar plano' : 'Ativar plano'),
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
