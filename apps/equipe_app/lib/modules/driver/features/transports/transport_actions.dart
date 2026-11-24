import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show showAppConfirmation;
import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../domain/models.dart';
import '../../domain/policies/transport_transitions.dart';
import '../../state/app_scope.dart';

Future<void> performPrimaryAction(
  BuildContext context,
  String transportId,
) async {
  final controller = AppScope.of(context);
  final transport = controller.transportById(transportId);
  final next = nextTransportStatus(transport.status);
  if (next == null) return;

  if (controller.readOnly || controller.busy) return;
  if (next == TransportStatus.petCollected) {
    await _checkCollection(context, transport);
    return;
  }
  final confirmed = await _confirmTransition(context, transport);
  if (!confirmed ||
      !context.mounted ||
      controller.activeTenantId != transport.tenantId) {
    return;
  }

  final success = await controller.transition(
    transport.id,
    transport.status,
    next,
  );
  if (!context.mounted) return;
  if (!success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          controller.error ?? 'Não foi possível confirmar a operação.',
        ),
      ),
    );
    return;
  }
  if (next == TransportStatus.delivered) {
    await _showCompleted(context, transport);
  }
}

String _collectedPetsLabel(TransportJob transport) => [
  for (var i = 0; i < transport.pets.length; i++)
    if (transport.collectionChecks == null ||
        transport.collectionChecks!.any(
          (check) => check.petId == transport.petIdAt(i) && check.confirmed,
        ))
      transport.pets[i].name,
].join(', ');

Future<bool> _confirmTransition(BuildContext context, TransportJob transport) {
  final (title, description, confirmLabel) = switch (transport.status) {
    TransportStatus.assigned => (
      'Iniciar deslocamento?',
      'Destino: ${transport.origin.fullAddress}',
      'Iniciar',
    ),
    TransportStatus.petCollected => (
      'Iniciar transporte?',
      'Destino: ${transport.destination.name}\n${transport.destination.fullAddress}',
      'Iniciar transporte',
    ),
    TransportStatus.inTransit => (
      'Confirmar entrega?',
      'Confirme somente após entregar todos os pets coletados: ${_collectedPetsLabel(transport)}.\n\nDestino: ${transport.destination.name}\n${transport.destination.fullAddress}\n\nSe houver algum impedimento, cancele e registre uma ocorrência.',
      'Confirmar entrega',
    ),
    _ => ('Confirmar ação?', '', 'Confirmar'),
  };
  return showAppConfirmation(
    context,
    title: title,
    message: description,
    confirmLabel: confirmLabel,
  );
}

Future<void> showIncidentSheet(BuildContext context, String transportId) async {
  const types = [
    'Tutor ausente',
    'Endereço não localizado',
    'Atraso',
    'Problema com veículo',
    'Problema durante transporte',
    'Outro',
  ];
  var type = types.first;
  final description = TextEditingController();
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setState) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Registrar ocorrência',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: const InputDecoration(
                labelText: 'Tipo da ocorrência',
              ),
              items: types
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => type = value!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: description,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Observação',
                hintText: 'Descreva brevemente o ocorrido...',
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => Navigator.pop(sheetContext, true),
              child: const Text('Registrar ocorrência'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(sheetContext, false),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    ),
  );
  if (saved == true && context.mounted) {
    final success = await AppScope.of(
      context,
    ).addIncident(transportId, type, description.text.trim());
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Ocorrência registrada.'
                : 'Não foi possível registrar a ocorrência.',
          ),
        ),
      );
    }
  }
  description.dispose();
}

Future<void> _checkCollection(
  BuildContext context,
  TransportJob transport,
) async {
  final indices = List.generate(transport.pets.length, (i) => i);
  final confirmed = {for (final i in indices) i: false};
  final reasons = {for (final i in indices) i: ''};
  final form = GlobalKey<FormState>();
  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Conferir coleta dos pets'),
        scrollable: true,
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Marque cada pet coletado. Para os demais, informe o motivo.',
              ),
              for (final i in indices) ...[
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(transport.pets[i].name),
                  value: confirmed[i],
                  onChanged: (v) => setState(() => confirmed[i] = v ?? false),
                ),
                if (confirmed[i] != true)
                  TextFormField(
                    key: ValueKey('reason-$i'),
                    initialValue: reasons[i],
                    decoration: const InputDecoration(
                      labelText: 'Motivo da exceção',
                    ),
                    onChanged: (v) => reasons[i] = v,
                    validator: (v) => v == null || v.trim().length < 3
                        ? 'Informe um motivo com pelo menos 3 caracteres'
                        : null,
                  ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Salvar conferência'),
          ),
        ],
      ),
    ),
  );
  if (saved != true || !context.mounted) return;
  final controller = AppScope.of(context);
  if (controller.activeTenantId != transport.tenantId) return;
  final checks = [
    for (final i in indices)
      TransportPetCheck(
        transport.petIdAt(i),
        confirmed[i]!,
        confirmed[i] == true ? '' : reasons[i]!.trim(),
      ),
  ];
  if (!await controller.checkPets(transport.id, 'COLLECTION', checks) ||
      !context.mounted) {
    return;
  }
  final canContinue = checks.any((c) => c.confirmed);
  if (canContinue && controller.activeTenantId == transport.tenantId) {
    await controller.transition(
      transport.id,
      transport.status,
      TransportStatus.petCollected,
    );
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        controller.error ??
            (canContinue
                ? 'Etapa confirmada.'
                : 'Conferência salva. A tarefa permanece pendente; a equipe pode tratar a ocorrência.'),
      ),
    ),
  );
}

Future<void> _showCompleted(
  BuildContext context,
  TransportJob transport,
) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(
        Icons.check_circle_rounded,
        size: 52,
        color: AppColors.primary,
      ),
      title: const Text('Transporte concluído'),
      content: Text(
        'Entrega de ${_collectedPetsLabel(transport)} confirmada no destino previsto.',
        textAlign: TextAlign.center,
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Próximo transporte'),
        ),
      ],
    ),
  );
}
