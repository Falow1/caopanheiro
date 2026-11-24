import 'package:caopanheiro_core/caopanheiro_core.dart';
import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppConfirmTone, AppRadii, showAppConfirmation;

import '../../core/formatters.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';
import '../../state/app_scope.dart';

class BlockFormScreen extends StatefulWidget {
  const BlockFormScreen({super.key, this.block});
  final ScheduleBlock? block;
  @override
  State<BlockFormScreen> createState() => _BlockFormScreenState();
}

class _BlockFormScreenState extends State<BlockFormScreen> {
  late DateTime _date = widget.block?.date ?? DateTime.now();
  late final _blockId = widget.block?.id ?? newRecordId();
  late final _start = TextEditingController(
    text: widget.block?.start ?? '12:00',
  );
  late final _end = TextEditingController(text: widget.block?.end ?? '14:00');
  late final _reason = TextEditingController(text: widget.block?.reason);
  late bool _fullDay = widget.block?.fullDay ?? false;

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    _reason.dispose();
    super.dispose();
  }

  bool _allowed() {
    final c = AppScope.of(context);
    final user = c.user;
    return user != null &&
        (user.isManager ||
            (user.canManageBlocks &&
                (widget.block == null || widget.block!.canEditNow)));
  }

  Future<void> _save() async {
    if (!_allowed()) return;
    final controller = AppScope.of(context);
    if (_reason.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o motivo do bloqueio.')),
      );
      return;
    }
    final value = ScheduleBlock(
      id: _blockId,
      date: _date,
      start: _start.text,
      end: _end.text,
      reason: _reason.text.trim(),
      fullDay: _fullDay,
    );
    // An edit is one save with the same id: the server replaces the block, so a
    // refused save (for example, a conflict with an appointment) keeps the old one.
    final saved = await controller.saveBlock(value);
    if (mounted && saved) {
      Navigator.pop(context);
    }
  }

  Future<void> _confirmRemoval() async {
    if (!_allowed()) return;
    final block = widget.block!;
    final period = block.fullDay
        ? 'dia inteiro'
        : '${block.start} — ${block.end}';
    final confirmed = await showAppConfirmation(
      context,
      title: 'Remover bloqueio?',
      message:
          'O bloqueio de ${date(block.date)}, $period, será removido e esse horário volta a ficar disponível para agendamentos. Esta ação não pode ser desfeita.',
      confirmLabel: 'Remover',
      tone: AppConfirmTone.danger,
    );
    if (!confirmed || !mounted || !_allowed()) return;
    final removed = await AppScope.of(context).removeBlock(block.id);
    if (mounted && removed) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => FormScaffold(
    title: widget.block == null ? 'Novo bloqueio' : 'Editar bloqueio',
    child: !_allowed()
        ? const PermissionNotice(
            message:
                'Somente o gestor pode alterar bloqueios de outras pessoas ou períodos já iniciados.',
          )
        : AppScope.of(context).catalogOffline
        ? const PermissionNotice(message: 'Alterações exigem conexão.')
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Bloqueio pontual para uma única data. Agendamentos em conflito precisam ser resolvidos na Agenda antes de salvar.',
              ),
              if (!AppScope.of(context).user!.isManager)
                const Text(
                  'Você pode criar bloqueios futuros e alterar ou remover apenas os seus. Funcionamento e disponibilidade recorrente são definidos pelo gestor.',
                ),
              if (AppScope.of(context).error != null)
                Text(AppScope.of(context).error!),
              ListTile(
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: AppRadii.r15),
                title: const Text('Data'),
                subtitle: Text(date(_date)),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: () async {
                  final value = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(DateTime.now().year + 5),
                  );
                  if (value != null) setState(() => _date = value);
                },
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                value: _fullDay,
                onChanged: (value) => setState(() => _fullDay = value),
                title: const Text('Dia inteiro'),
                contentPadding: EdgeInsets.zero,
              ),
              if (!_fullDay) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _start,
                        decoration: const InputDecoration(labelText: 'Início'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _end,
                        decoration: const InputDecoration(labelText: 'Fim'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
              TextField(
                controller: _reason,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Motivo (obrigatório)',
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: AppScope.of(context).busy ? null : _save,
                child: const Text('Salvar'),
              ),
              if (widget.block != null) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: AppScope.of(context).busy ? null : _confirmRemoval,
                  child: const Text('Remover bloqueio'),
                ),
              ],
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ],
          ),
  );
}
