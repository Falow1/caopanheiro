import 'package:caopanheiro_core/caopanheiro_core.dart';
import 'package:flutter/material.dart';

import '../../core/widgets.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppTextStyles, showAppConfirmation;
import '../../domain/models.dart';
import '../../state/app_scope.dart';

class ServiceFormScreen extends StatefulWidget {
  const ServiceFormScreen({super.key, this.service});
  final PetService? service;
  @override
  State<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends State<ServiceFormScreen> {
  late final _serviceId = widget.service?.id ?? newRecordId();
  final _key = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.service?.name);
  late final _description = TextEditingController(
    text: widget.service?.description,
  );
  late final _duration = TextEditingController(
    text: widget.service?.duration.toString(),
  );
  late final _price = TextEditingController(
    text: widget.service?.price.toStringAsFixed(2).replaceAll('.', ','),
  );
  late bool _active = widget.service?.active ?? true;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _duration.dispose();
    _price.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Preencha este campo' : null;

  int? _cents(String text) {
    final value = text.trim();
    if (!RegExp(r'^\d+(?:[,.]\d{1,2})?$').hasMatch(value)) return null;
    final parts = value.replaceAll(',', '.').split('.');
    final whole = int.tryParse(parts.first);
    if (whole == null) return null;
    final cents =
        whole * 100 +
        (parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0')));
    return cents <= 9007199254740991 ? cents : null;
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    final controller = AppScope.of(context);
    if (controller.busy ||
        controller.catalogOffline ||
        (controller.user?.isManager != true ||
            controller.user?.canManage('SERVICES') != true)) {
      return;
    }
    final cents = _cents(_price.text)!;
    if (cents == 0) {
      final confirmed = await showAppConfirmation(
        context,
        title: 'Serviço gratuito',
        message: 'Este serviço será gratuito. Deseja continuar?',
        confirmLabel: 'Confirmar',
        cancelLabel: 'Voltar',
      );
      if (!confirmed || !mounted) return;
    }
    final value = PetService(
      id: _serviceId,
      name: _name.text.trim(),
      description: _description.text.trim(),
      duration: int.parse(_duration.text),
      price: cents / 100,
      active: _active,
    );
    if (await controller.saveService(value, original: widget.service) &&
        mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => FormScaffold(
    title: widget.service == null ? 'Novo serviço' : 'Editar serviço',
    child:
        (AppScope.of(context).user?.isManager != true ||
                AppScope.of(context).user?.canManage('SERVICES') != true) ||
            AppScope.of(context).catalogOffline
        ? PermissionNotice(
            message: AppScope.of(context).catalogOffline
                ? 'Conecte-se e atualize o catálogo para alterar serviços.'
                : 'Seu perfil não possui permissão para esta ação.',
          )
        : Form(
            key: _key,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _name,
                  validator: (value) {
                    final required = _required(value);
                    if (required != null) return required;
                    return value!.trim().length < 2 || value.trim().length > 100
                        ? 'Use entre 2 e 100 caracteres.'
                        : null;
                  },
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _description,
                  validator: (value) => (value?.trim().length ?? 0) > 1000
                      ? 'Use até 1.000 caracteres.'
                      : null,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Descrição'),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _duration,
                        validator: (value) {
                          final required = _required(value);
                          if (required != null) return required;
                          final duration = int.tryParse(value!.trim());
                          return duration == null ||
                                  duration <= 0 ||
                                  duration > 9007199254740991
                              ? 'Informe minutos inteiros positivos.'
                              : null;
                        },
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Duração (min)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _price,
                        validator: (value) =>
                            _required(value) ??
                            (_cents(value!) == null
                                ? 'Informe um valor válido, sem sinal e com até 2 casas decimais.'
                                : null),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Valor (R\$)',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SwitchListTile(
                  value: _active,
                  onChanged: (value) => setState(() => _active = value),
                  title: Text(_active ? 'Serviço ativo' : 'Serviço inativo'),
                  subtitle: Text(
                    _active
                        ? 'Disponível em novos agendamentos'
                        : 'Oculto em novos agendamentos',
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: AppScope.of(context).busy ? null : _save,
                  child: const Text('Salvar'),
                ),
                if (widget.service != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: AppScope.of(context).busy
                        ? null
                        : () {
                            setState(() => _active = !_active);
                            _save();
                          },
                    child: Text(
                      _active ? 'Desativar serviço' : 'Ativar serviço',
                    ),
                  ),
                ],
                if (AppScope.of(context).error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      AppScope.of(context).error!,
                      style: AppTextStyles.danger,
                    ),
                  ),
                TextButton(
                  onPressed: AppScope.of(context).busy
                      ? null
                      : () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ),
  );
}
