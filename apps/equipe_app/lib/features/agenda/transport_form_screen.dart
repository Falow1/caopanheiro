import 'package:caopanheiro_core/caopanheiro_core.dart';
import 'package:flutter/material.dart';

import '../../core/formatters.dart' as fmt;
import '../../state/app_scope.dart';
import 'transport_management_screen.dart';
import '../../domain/repositories/transport_management_repository.dart';

class TransportFormScreen extends StatefulWidget {
  const TransportFormScreen({super.key, required this.appointmentId});
  final String appointmentId;
  @override
  State<TransportFormScreen> createState() => _TransportFormScreenState();
}

class _TransportFormScreenState extends State<TransportFormScreen> {
  final _key = GlobalKey<FormState>();
  final _id = newRecordId();
  final _origin = {
    for (final field in ['name', 'street', 'district', 'phone'])
      field: TextEditingController(),
  };
  final _destination = {
    for (final field in ['name', 'street', 'district', 'phone'])
      field: TextEditingController(),
  };
  final _notes = TextEditingController();
  List<CompanyDriver> _drivers = [];
  String? _driver;
  int? _minutes;
  // The addresses the minutes were calculated for, and why they are missing.
  String? _routeKey, _routeNote;
  bool _estimating = false;
  bool _saving = false;
  String _type = 'PICKUP';
  DateTime _at = DateTime.now().add(const Duration(hours: 1));
  bool _loading = true;
  bool _allowed = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    for (final field in [..._origin.values, ..._destination.values, _notes]) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final controller = AppScope.of(context);
      if (!controller.user!.canManage('TRANSPORT')) {
        throw const FormatException(
          'Seu acesso não permite gerenciar transportes.',
        );
      }
      if (!controller.user!.isManager &&
          (await controller.bookingPolicy())['enabled'] != true) {
        if (mounted) {
          setState(
            () => _error =
                'Novos transportes estão desativados. Solicite a ativação ao gestor.',
          );
        }
        return;
      }
      final drivers = await controller.getDrivers();
      if (mounted) {
        setState(() {
          _drivers = drivers;
          _allowed = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Não foi possível consultar os entregadores. Atualize com conexão.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _time() async {
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: _at,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_at),
    );
    if (time != null && mounted) {
      setState(
        () => _at = DateTime(
          day.year,
          day.month,
          day.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  Future<void> _save() async {
    if (!_allowed) return;
    if (!_key.currentState!.validate() || _driver == null) return;
    if (_saving) return;
    final controller = AppScope.of(context);
    final originalCompany = controller.company?.id;
    final originalSession = controller.sessionKey;
    setState(() => _saving = true);
    try {
      final origin = _origin.map(_typed);
      final destination = _destination.map(_typed);
      await _estimate(origin, destination);
      if (!mounted) return;
      final driverUid = _driver!,
          scheduledAt = _at,
          minutes = _minutes,
          type = _type;
      final notes = _notes.text.trim();
      final preview = await controller.transportConflicts(
        driverUid,
        scheduledAt,
        minutes,
        appointmentId: widget.appointmentId,
      );
      if (!mounted ||
          !await confirmTransportConflicts(context, preview) ||
          !mounted) {
        return;
      }
      if (controller.company?.id != originalCompany ||
          controller.sessionKey != originalSession) {
        return;
      }
      final request = TransportRequest(
        id: _id,
        appointmentId: widget.appointmentId,
        driverUid: driverUid,
        type: type,
        scheduledAt: scheduledAt,
        origin: origin,
        destination: destination,
        notes: notes,
        estimatedDurationMinutes: minutes,
        conflictAcknowledgement: preview.acknowledgement,
      );
      if (await AppScope.of(context).createTransport(request) && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Transporte confirmado.')));
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// The minutes of the trip by the streets between the two addresses,
  /// calculated once for each pair of addresses typed.
  Future<void> _estimate(
    Map<String, String> origin,
    Map<String, String> destination,
  ) async {
    final key = [
      origin['street'],
      origin['district'],
      destination['street'],
      destination['district'],
    ].join('|');
    if (key == _routeKey || _estimating) return;
    setState(() => _estimating = true);
    final minutes = await AppScope.of(
      context,
    ).estimateTrip(origin, destination);
    if (!mounted) return;
    setState(() {
      _estimating = false;
      _routeKey = key;
      _minutes = minutes;
      _routeNote = minutes == null
          ? 'Não foi possível calcular a rota agora. O aviso de conflito considera só horários iguais.'
          : null;
    });
  }

  /// The typed value of an address field; the phone goes formatted.
  static MapEntry<String, String> _typed(
    String key,
    TextEditingController field,
  ) => MapEntry(
    key,
    key == 'phone'
        ? formatBrazilPhone(field.text) ?? field.text.trim()
        : field.text.trim(),
  );

  List<Widget> _address(
    String title,
    Map<String, TextEditingController> fields,
  ) => [
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
    ),
    for (final entry in fields.entries)
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: entry.value,
          keyboardType: entry.key == 'phone' ? TextInputType.phone : null,
          inputFormatters: entry.key == 'phone'
              ? const [PhoneInputFormatter()]
              : null,
          validator: entry.key == 'phone'
              ? phoneValidator
              : (value) => value == null || value.trim().isEmpty
                    ? 'Preencha este campo'
                    : null,
          decoration: InputDecoration(
            hintText: entry.key == 'phone' ? phoneHint : null,
            labelText: const {
              'name': 'Nome do local/contato',
              'street': 'Endereço completo',
              'district': 'Bairro',
              'phone': 'Telefone',
            }[entry.key],
          ),
        ),
      ),
  ];
  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    if (controller.user == null) return const SizedBox.shrink();
    if (!_loading && !_allowed) {
      return Scaffold(
        appBar: AppBar(title: const Text('Agendar transporte')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error ??
                'Não foi possível verificar a disponibilidade do transporte.',
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Agendar transporte')),
      body: Form(
        key: _key,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Escolha um entregador vinculado à empresa. Os pets serão obtidos do agendamento no servidor.',
            ),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (_error != null) Text(_error!),
            if (!_loading && _drivers.isEmpty)
              const Text(
                'Nenhum entregador ativo. Vincule uma conta pelo aplicativo SaaS.',
              ),
            TextButton(
              onPressed: _loading ? null : _load,
              child: const Text('Atualizar entregadores'),
            ),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _driver,
              decoration: const InputDecoration(labelText: 'Entregador'),
              items: _drivers
                  .map(
                    (driver) => DropdownMenuItem(
                      value: driver.id,
                      child: Text(driver.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _driver = value),
              validator: (value) =>
                  value == null ? 'Selecione um entregador' : null,
            ),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: const [
                DropdownMenuItem(value: 'PICKUP', child: Text('Buscar pet')),
                DropdownMenuItem(
                  value: 'RETURN',
                  child: Text('Levar pet de volta'),
                ),
              ],
              onChanged: (value) => setState(() => _type = value!),
            ),
            // The day and time of this trip, on the clock of the petshop.
            OutlinedButton.icon(
              onPressed: _time,
              icon: const Icon(Icons.schedule_rounded),
              label: Text(
                '${_type == 'PICKUP' ? 'Buscar o pet' : 'Levar de volta'} em '
                '${fmt.date(_at)} às ${fmt.time(_at)}',
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                'Horário local do petshop.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.route_outlined),
              title: const Text('Duração estimada da viagem'),
              subtitle: Text(
                _estimating
                    ? 'Calculando pela rota...'
                    : _minutes != null
                    ? '$_minutes min pela rota entre os endereços'
                    : _routeNote ??
                          'Calculada pela distância entre os endereços ao confirmar.',
              ),
            ),
            ..._address('Origem', _origin),
            ..._address('Destino', _destination),
            TextFormField(
              controller: _notes,
              maxLength: 1000,
              decoration: const InputDecoration(labelText: 'Observações'),
            ),
            if (controller.error != null) Text(controller.error!),
            FilledButton(
              onPressed:
                  controller.busy ||
                      controller.catalogOffline ||
                      _loading ||
                      _saving
                  ? null
                  : _save,
              child: const Text('Confirmar transporte'),
            ),
          ],
        ),
      ),
    );
  }
}
