import 'dart:async';
import 'package:flutter/material.dart';
import '../../state/app_scope.dart';
import '../../core/utils/formatters.dart';
import '../navigation/tutor_wide_layout.dart';

/// Transport time on the company wall clock (the petshop's own city), as the
/// appointment time; older answers without it fall back to this device.
DateTime? transportCompanyTime(Map<String, dynamic> row) {
  final local = row['localScheduledAt'];
  if (local is String) return DateTime.tryParse(local);
  final value = row['scheduledAt'];
  return value is String ? DateTime.tryParse(value)?.toLocal() : null;
}

class TransportTrackingCard extends StatefulWidget {
  const TransportTrackingCard({
    super.key,
    required this.appointmentId,
    this.servicesPrice = 0,
    this.hideWhenEmpty = false,
  });
  final String appointmentId;
  final double servicesPrice;

  /// Shows nothing while there is no transport, instead of an empty card.
  final bool hideWhenEmpty;
  @override
  State<TransportTrackingCard> createState() => _TransportTrackingCardState();
}

class _TransportTrackingCardState extends State<TransportTrackingCard>
    with WidgetsBindingObserver {
  Timer? _timer;
  List<Map<String, dynamic>> _rows = [];
  String? _error, _company;
  bool _loading = false, _active = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _company = AppScope.of(context).companyId;
      _load();
    });
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_active && mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
        _load();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active) _load();
  }

  Future<void> _load() async {
    if (!mounted || _loading) return;
    final c = AppScope.of(context);
    if (c.companyId != _company) {
      setState(() {
        _rows = [];
        _error = 'A empresa mudou. Volte para seus agendamentos.';
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final result = await c.trackTransport(widget.appointmentId);
      if (mounted && c.companyId == _company) {
        setState(() {
          _rows = (result['items'] as List)
              .map((r) => Map<String, dynamic>.from(r as Map))
              .toList();
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _rows = [];
          _error =
              'Não foi possível atualizar o transporte. Confira a conexão.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static bool _open(Map<String, dynamic> row) =>
      const ['REQUESTED', 'CONFIRMED'].contains(row['status']);
  num get _fees => _rows
      .where((row) => _open(row) && row['feeCents'] is num)
      .fold<num>(0, (total, row) => total + (row['feeCents'] as num));

  @override
  Widget build(BuildContext context) {
    if (widget.hideWhenEmpty && _rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: _card(context),
    );
  }

  Widget _card(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Transporte dos seus pets',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Text(
            'O entregador marca cada etapa, e esta tela se atualiza sozinha enquanto estiver aberta. A localização em tempo real não aparece.',
          ),
          if (_error != null) Text(_error!),
          for (final row in _rows) ...[
            const Divider(height: 24),
            Text(
              row['feeCents'] is num
                  ? '${row['type'] == 'PICKUP' ? 'Coleta' : 'Retorno'} · ${formatMoney((row['feeCents'] as num) / 100)}'
                  : '${row['type'] == 'PICKUP' ? 'Coleta' : 'Retorno'} · agendado pela equipe',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text('${row['origin']['name']} → ${row['destination']['name']}'),
            if (row['openIncident'] == true)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Houve uma ocorrência neste transporte. A equipe do petshop está acompanhando; em caso de dúvida, fale com o petshop.',
                ),
              ),
            if (row['status'] == 'REQUESTED')
              const Text('Pedido recebido · aguardando confirmação da equipe'),
            if (row['status'] == 'REJECTED')
              Text(
                'Pedido não confirmado: ${row['reason']}. Esta taxa não será cobrada.',
              ),
            if (row['status'] == 'CANCELLED')
              const Text('Transporte cancelado. Esta taxa não será cobrada.'),
            if (row['status'] == 'CONFIRMED') ...[
              if (row['scheduledAt'] != null)
                Text(
                  'Horário: ${formatDateTime(transportCompanyTime(row)!)}',
                ),
              _Progress(
                status: row['transportStatus'] as String? ?? 'ASSIGNED',
              ),
            ],
          ],
          if (_rows.any((row) => row['feeCents'] is num))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Total previsto com serviços: ${formatMoney(widget.servicesPrice + _fees / 100)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          if (_rows.isEmpty && _error == null && !_loading)
            const Text('Nenhum transporte solicitado.'),
          TutorRefreshButton(
            label: _loading ? 'Atualizando…' : 'Atualizar transporte',
            onRefresh: _load,
            loading: _loading,
          ),
        ],
      ),
    ),
  );
}

class _Progress extends StatelessWidget {
  const _Progress({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    const stages = [
      'ASSIGNED',
      'GOING_TO_ORIGIN',
      'PET_COLLECTED',
      'IN_TRANSIT',
      'DELIVERED',
    ];
    const labels = [
      'Entregador definido',
      'A caminho da coleta',
      'Pets coletados',
      'Levando seus pets ao destino',
      'Entrega confirmada',
    ];
    final index = stages.indexOf(status);
    if (index < 0) {
      return const Text('Transporte cancelado. Esta taxa não será cobrada.');
    }
    return Semantics(
      label: '${labels[index]}, etapa ${index + 1} de 5',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Text(labels[index], style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Row(
            children: List.generate(
              5,
              (i) => Expanded(
                child: Container(
                  height: 7,
                  margin: EdgeInsets.only(right: i == 4 ? 0 : 4),
                  decoration: BoxDecoration(
                    color: i <= index
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text('Etapa ${index + 1} de 5'),
        ],
      ),
    );
  }
}
