import 'package:flutter/material.dart';
import '../../state/app_scope.dart';
import '../../domain/repositories/transport_management_repository.dart';
import 'transport_management_screen.dart';

class TransportRequestsScreen extends StatefulWidget {
  const TransportRequestsScreen({super.key});
  @override
  State<TransportRequestsScreen> createState() =>
      _TransportRequestsScreenState();
}

class _TransportRequestsScreenState extends State<TransportRequestsScreen> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  bool _canAccept = false;
  String? _error, _company;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _company = AppScope.of(context).company?.id;
      _load();
    });
  }

  bool get _sameCompany => AppScope.of(context).company?.id == _company;
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final controller = AppScope.of(context);
      final rows = await controller.bookingRequests();
      var enabled = controller.user?.isManager == true;
      if (!enabled) {
        try {
          enabled = (await controller.bookingPolicy())['enabled'] == true;
        } catch (_) {
          enabled = false;
        }
      }
      if (mounted && _sameCompany) {
        setState(() {
          _rows = rows;
          _canAccept = enabled;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decide(Map<String, dynamic> row, bool accept) async {
    final c = AppScope.of(context);
    if (!_sameCompany || (accept && !_canAccept)) return;
    if (!accept) {
      var reason = '';
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => StatefulBuilder(
          builder: (context, change) => AlertDialog(
            title: const Text('Não confirmar transporte'),
            scrollable: true,
            content: TextField(
              decoration: const InputDecoration(
                labelText: 'Motivo para o tutor',
              ),
              onChanged: (v) => change(() => reason = v.trim()),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: const Text('Voltar'),
              ),
              FilledButton(
                onPressed: reason.length < 3
                    ? null
                    : () => Navigator.pop(dialog, true),
                child: const Text('Informar ao tutor'),
              ),
            ],
          ),
        ),
      );
      if (confirmed == true && mounted && _sameCompany) {
        await c.decideBookingRequest({
          'transportRequestId': row['id'],
          'accept': false,
          'reason': reason,
        });
        if (mounted) {
          if (c.error != null) {
            setState(() => _error = c.error);
          } else {
            await _load();
          }
        }
      }
      return;
    }
    setState(() => _loading = true);
    List<CompanyDriver> drivers;
    try {
      drivers = await c.getDrivers();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
      return;
    }
    if (!mounted || !_sameCompany) return;
    setState(() => _loading = false);
    if (drivers.isEmpty) {
      setState(() => _error = 'Nenhum entregador ativo cadastrado.');
      return;
    }
    String? selected;
    DateTime? scheduled;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, change) => AlertDialog(
          title: Text(
            row['type'] == 'PICKUP' ? 'Confirmar coleta' : 'Confirmar retorno',
          ),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Atendimento: ${(row['appointmentLocalStartsAt'] as String?)?.substring(0, 16).replaceFirst('T', ' ') ?? 'Consulte a agenda'} (horário do petshop). Coleta deve ocorrer antes do atendimento; retorno aguarda sua conclusão.',
              ),
              DropdownButtonFormField<String>(
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Entregador'),
                items: drivers
                    .map(
                      (d) => DropdownMenuItem(value: d.id, child: Text(d.name)),
                    )
                    .toList(),
                onChanged: (v) => change(() => selected = v),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () async {
                  final now = DateTime.now();
                  final day = await showDatePicker(
                    context: context,
                    initialDate: now,
                    firstDate: DateTime(now.year, now.month, now.day),
                    lastDate: DateTime(now.year + 2),
                  );
                  if (day == null || !context.mounted) return;
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (time != null && context.mounted) {
                    change(
                      () => scheduled = DateTime(
                        day.year,
                        day.month,
                        day.day,
                        time.hour,
                        time.minute,
                      ),
                    );
                  }
                },
                child: Text(
                  scheduled == null
                      ? 'Escolher data e horário'
                      : scheduled.toString().substring(0, 16),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Voltar'),
            ),
            FilledButton(
              onPressed: selected == null || scheduled == null
                  ? null
                  : () => Navigator.pop(dialog, true),
              child: const Text('Revisar e confirmar'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || !mounted || !_sameCompany) return;
    try {
      final preview = await c.transportConflicts(
        selected!,
        scheduled!,
        null,
        appointmentId: row['appointmentId'] as String,
      );
      if (!mounted || !_sameCompany) return;
      if (!await confirmTransportConflicts(context, preview) ||
          !mounted ||
          !_sameCompany) {
        return;
      }
      setState(() => _loading = true);
      final success = await c.decideBookingRequest({
        'transportRequestId': row['id'],
        'accept': true,
        'driverUid': selected,
        'localScheduledAt': companyClockLabel(scheduled!),
        'conflictAcknowledgement': preview.acknowledgement,
      });
      if (mounted) {
        if (success) {
          await _load();
        } else {
          setState(() => _error = c.error);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pedidos dos tutores')),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Confirme disponibilidade, horário e entregador. A taxa aceita pelo tutor é preservada. Recusas ficam visíveis ao tutor e não geram transporte.',
          ),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_error != null) Text(_error!),
          if (!_loading && _rows.isEmpty)
            const Text('Nenhum pedido de transporte.'),
          for (final row in _rows)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${row['type'] == 'PICKUP' ? 'Coleta' : 'Retorno'} · ${(row['pets'] as List).map((p) => p['name']).join(', ')}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${row['origin']['name']} → ${row['destination']['name']}',
                    ),
                    Text(
                      '${row['origin']['street']} → ${row['destination']['street']}',
                    ),
                    Text(
                      'Taxa: R\$ ${(row['feeCents'] / 100).toStringAsFixed(2).replaceAll('.', ',')} · ${(row['meters'] / 1000).toStringAsFixed(2)} km',
                    ),
                    Text(switch (row['status']) {
                      'REQUESTED' => 'Aguardando confirmação',
                      'CONFIRMED' => 'Confirmado',
                      'REJECTED' => 'Não confirmado: ${row['reason']}',
                      'CANCELLED' => 'Cancelado',
                      _ => 'Atualize o pedido',
                    }),
                    if (row['status'] == 'REQUESTED') ...[
                      if (!_canAccept)
                        const Text(
                          'Novos transportes estão desativados pelo gestor.',
                        ),
                      const SizedBox(height: 10),
                      if (_canAccept)
                        FilledButton(
                          onPressed: _loading ? null : () => _decide(row, true),
                          child: const Text('Definir entregador e confirmar'),
                        ),
                      TextButton(
                        onPressed: _loading ? null : () => _decide(row, false),
                        child: const Text('Não confirmar'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
