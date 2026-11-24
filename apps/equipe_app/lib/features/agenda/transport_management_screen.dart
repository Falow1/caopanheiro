import 'package:equipe_app/domain/policies/transport_review.dart';
import 'appointment_detail_screen.dart';
import 'package:flutter/material.dart';
import '../../domain/repositories/transport_management_repository.dart';
import '../../core/live_screen_reload.dart';
import '../../state/app_scope.dart';

Future<bool> confirmTransportConflicts(
  BuildContext context,
  TransportConflictPreview preview,
) async {
  if (preview.messages.isEmpty && !preview.incomplete) return true;
  return await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Revisar agenda do entregador'),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Avaliação somente desta empresa. Viagens agrupadas podem ser permitidas; revise antes de confirmar.',
              ),
              if (preview.incomplete)
                const Text(
                  'Há tarefas sem duração estimada. Nesses casos, só horários exatamente iguais geram aviso; outros conflitos podem não ser detectados.',
                ),
              for (final message in preview.messages)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(message),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Voltar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Confirmar avisos'),
            ),
          ],
        ),
      ) ??
      false;
}

class TransportManagementScreen extends StatefulWidget {
  const TransportManagementScreen({
    super.key,
    this.appointmentId,
    this.reviewOnly = false,
  });
  final bool reviewOnly;
  final String? appointmentId;
  @override
  State<TransportManagementScreen> createState() =>
      _TransportManagementScreenState();
}

class _TransportManagementScreenState extends State<TransportManagementScreen>
    with LiveScreenReload {
  List<ManagedTransport> _items = [];
  List<CompanyDriver> _drivers = [];
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void liveScreenReload() {
    if (!_loading) _load(quiet: true);
  }

  /// [quiet]: live refresh, without loading state; a failure keeps the list.
  Future<void> _load({bool quiet = false}) async {
    if (!quiet) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final controller = AppScope.of(context);
    final company = controller.company?.id;
    try {
      final items = await controller.getTransports(
        appointmentId: widget.appointmentId,
      );
      final drivers = await controller.getDrivers();
      if (mounted &&
          controller.user != null &&
          controller.company?.id == company) {
        setState(() {
          _items = items;
          _drivers = drivers;
        });
      }
    } catch (e) {
      if (mounted && !quiet) setState(() => _error = e.toString());
    } finally {
      if (mounted && !quiet) setState(() => _loading = false);
    }
  }

  Future<void> _reassign(ManagedTransport transport) async {
    final controller = AppScope.of(context);
    final manager = controller.user?.isManager == true;
    final company = controller.company?.id;
    final session = controller.sessionKey;
    if (transport.inCustody && !manager) {
      setState(
        () => _error =
            'Somente gestor pode confirmar a transferência física de pets já coletados.',
      );
      return;
    }
    String? selected;
    var reason = '';
    var custody = false;
    final form = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Trocar responsável'),
          scrollable: true,
          content: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Novo entregador',
                  ),
                  items: _drivers
                      .where((d) => d.id != transport.driverUid)
                      .map(
                        (d) =>
                            DropdownMenuItem(value: d.id, child: Text(d.name)),
                      )
                      .toList(),
                  onChanged: (v) => selected = v,
                  validator: (v) =>
                      v == null ? 'Selecione outro entregador' : null,
                ),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Motivo da troca',
                  ),
                  onChanged: (v) => reason = v,
                  validator: (v) => v == null || v.trim().length < 3
                      ? 'Informe o motivo'
                      : null,
                ),
                if (transport.inCustody)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: custody,
                    onChanged: (v) => setState(() => custody = v ?? false),
                    title: const Text(
                      'Confirmo que os pets foram transferidos fisicamente ao novo entregador. Essa confirmação ficará registrada sob minha responsabilidade.',
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Voltar'),
            ),
            FilledButton(
              onPressed: transport.inCustody && !custody
                  ? null
                  : () {
                      if (form.currentState!.validate()) {
                        Navigator.pop(dialog, true);
                      }
                    },
              child: const Text('Continuar'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true ||
        !mounted ||
        controller.company?.id != company ||
        controller.sessionKey != session) {
      return;
    }
    try {
      final preview = await controller.transportConflicts(
        selected!,
        transport.scheduledAt,
        transport.estimatedDurationMinutes,
        excludeId: transport.id,
      );
      if (!mounted ||
          !await confirmTransportConflicts(context, preview) ||
          !mounted) {
        return;
      }
      if (controller.company?.id != company ||
          controller.sessionKey != session) {
        return;
      }
      final success = await controller.reassignTransport(
        transport,
        selected!,
        reason.trim(),
        custody,
        preview.acknowledgement,
      );
      if (mounted) {
        if (success) {
          await _load();
        } else {
          setState(() => _error = controller.error);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _incident(
    ManagedTransport t,
    ManagedIncident incident,
    bool resolve,
  ) async {
    final originalController = AppScope.of(context);
    final originalCompany = originalController.company?.id;
    final originalSession = originalController.sessionKey;
    var message = '';
    final form = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        scrollable: true,
        title: Text(resolve ? 'Resolver ocorrência' : 'Responder ocorrência'),
        content: Form(
          key: form,
          child: TextFormField(
            maxLines: 3,
            decoration: InputDecoration(
              labelText: resolve
                  ? 'Solução aplicada'
                  : 'Orientação ao entregador',
            ),
            onChanged: (v) => message = v,
            validator: (v) => v == null || v.trim().length < 3
                ? 'Descreva a orientação ou solução'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(dialog, true);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final c = AppScope.of(context);
    if (c.company?.id != originalCompany || c.sessionKey != originalSession) {
      return;
    }
    final success = await c.manageTransportIncident(
      t.id,
      incident.id,
      resolve ? 'RESOLVED' : 'ACKNOWLEDGED',
      message.trim(),
    );
    if (mounted) {
      if (success) {
        await _load();
      } else {
        setState(() => _error = c.error);
      }
    }
  }

  Future<void> _reviewAppointment(ManagedTransport transport) async {
    final c = AppScope.of(context), company = AppScope.of(context).company?.id;
    final loaded = await c.refreshAgenda();
    if (!mounted || c.company?.id != company) return;
    if (!loaded || c.readOnly) {
      setState(
        () => _error =
            c.agendaError ??
            'Atualize a agenda com conexão antes de revisar o transporte.',
      );
      return;
    }
    if (!c.appointments.any((item) => item.id == transport.appointmentId)) {
      if (mounted) {
        setState(() => _error = 'Agendamento indisponível. Atualize os dados.');
      }
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            AppointmentDetailScreen(appointmentId: transport.appointmentId),
      ),
    );
    if (mounted && c.company?.id == company) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    if (c.user == null) return const SizedBox.shrink();
    final disabled = _loading || c.busy || c.catalogOffline;
    final visible = _items
        .where(
          (t) =>
              !widget.reviewOnly ||
              transportNeedsReview(t.scheduledAt, t.status),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.reviewOnly
              ? 'Transportes para revisão'
              : 'Gestão de transportes',
        ),
        actions: [
          IconButton(
            onPressed: disabled ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (_error != null) Text(_error!),
                  if (c.catalogOffline)
                    const Text('Gestão de transportes exige conexão.'),
                  if (visible.isEmpty)
                    const Text('Nenhum transporte encontrado.'),
                  for (final t in visible)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '${t.type == 'PICKUP' ? 'Coleta' : 'Retorno'} · ${t.displayScheduledAt.toString().substring(0, 16)}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              'Situação: ${const {'ASSIGNED': 'Atribuído', 'GOING_TO_ORIGIN': 'A caminho da origem', 'PET_COLLECTED': 'Pets coletados', 'IN_TRANSIT': 'Em transporte', 'DELIVERED': 'Entregue', 'CANCELLED': 'Cancelado'}[t.status] ?? t.status}',
                            ),
                            if (transportNeedsReview(t.scheduledAt, t.status))
                              const Text('Atrasado — precisa de revisão'),
                            if (transportNeedsReview(
                              t.scheduledAt,
                              t.status,
                            )) ...[
                              const Text(
                                'Revise com o tutor. Remarcar ou cancelar o agendamento vinculado pode afetar seus outros transportes.',
                              ),
                              OutlinedButton(
                                onPressed: disabled
                                    ? null
                                    : () => _reviewAppointment(t),
                                child: const Text('Revisar agendamento'),
                              ),
                            ],
                            if (!t.finished &&
                                !transportNeedsReview(
                                  t.scheduledAt,
                                  t.status,
                                ) &&
                                t.scheduledAt.isBefore(DateTime.now()))
                              const Text(
                                'Pendente · horário previsto ultrapassado',
                              ),
                            Text(
                              'Entregador: ${_drivers.where((d) => d.id == t.driverUid).firstOrNull?.name ?? t.driverUid}',
                            ),
                            if (!t.finished)
                              OutlinedButton(
                                onPressed: disabled ? null : () => _reassign(t),
                                child: const Text('Trocar responsável'),
                              ),
                            for (final entry in t.history)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Text(entry),
                              ),
                            for (final check in t.checks) Text(check),
                            for (final i in t.incidents) ...[
                              const Divider(),
                              Text(
                                i.type,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              Text(i.description),
                              Text(
                                'Situação: ${i.status == 'RESOLVED'
                                    ? 'Resolvida'
                                    : i.status == 'ACKNOWLEDGED'
                                    ? 'Em atendimento'
                                    : 'Aberta'}',
                              ),
                              if (i.response.isNotEmpty)
                                Text('Resposta: ${i.response}'),
                              if (i.resolution.isNotEmpty)
                                Text('Solução: ${i.resolution}'),
                              if (i.status != 'RESOLVED')
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    TextButton(
                                      onPressed: disabled
                                          ? null
                                          : () => _incident(t, i, false),
                                      child: const Text('Responder'),
                                    ),
                                    TextButton(
                                      onPressed: disabled
                                          ? null
                                          : () => _incident(t, i, true),
                                      child: const Text('Resolver'),
                                    ),
                                  ],
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
}
