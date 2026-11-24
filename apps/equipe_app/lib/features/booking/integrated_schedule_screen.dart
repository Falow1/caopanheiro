import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppRefreshBody;

import '../../domain/models.dart';
import '../../domain/models/scheduling_policy.dart';
import '../../state/app_scope.dart';
import 'booking_draft.dart';
import 'booking_confirmation_screen.dart';

class IntegratedScheduleScreen extends StatefulWidget {
  const IntegratedScheduleScreen({super.key, required this.draft});
  final BookingDraft draft;
  @override
  State<IntegratedScheduleScreen> createState() =>
      _IntegratedScheduleScreenState();
}

class _IntegratedScheduleScreenState extends State<IntegratedScheduleScreen> {
  DateTime _day = DateTime.now();
  List<AvailableSlot> _slots = const [];
  AvailableSlot? _selected;
  bool _loading = false;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    if (widget.draft.editing && widget.draft.startsAt != null) {
      _day = widget.draft.displayStartsAt;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _selected = null;
      _slots = const [];
    });
    final draft = widget.draft;
    final items = draft.pets
        .map(
          (pet) => AppointmentItem(
            pet: pet,
            services: draft.services[pet.id]!.toList(),
          ),
        )
        .toList();
    final result = await AppScope.of(context).availableSlots(
      draft.customer.id,
      items,
      _day,
      appointmentId: draft.editing ? draft.appointmentId : null,
    );
    if (!mounted || request != _request) return;
    setState(() {
      _slots = result ?? const [];
      if (draft.editing) {
        _selected = _slots
            .where(
              (slot) =>
                  slot.startsAt.isAtSameMomentAs(draft.startsAt!) &&
                  slot.professionalId == draft.professionalId,
            )
            .firstOrNull;
      }
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Escolher horário')),
      body: AppRefreshBody(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Horários da empresa',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_month),
              label: Text(
                '${_day.day.toString().padLeft(2, '0')}/${_day.month.toString().padLeft(2, '0')}/${_day.year}',
              ),
              onPressed: _loading
                  ? null
                  : () async {
                      final today = DateUtils.dateOnly(DateTime.now());
                      final first = today.subtract(const Duration(days: 1));
                      final last = today.add(const Duration(days: 365));
                      final initial = _day.isBefore(first)
                          ? first
                          : _day.isAfter(last)
                          ? last
                          : _day;
                      final day = await showDatePicker(
                        context: context,
                        initialDate: initial,
                        firstDate: first,
                        lastDate: last,
                      );
                      if (day != null && mounted) {
                        setState(() => _day = day);
                        await _load();
                      }
                    },
            ),
            const SizedBox(height: 16),
            if (_loading) const LinearProgressIndicator(),
            if (controller.error != null)
              Text(
                controller.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (!_loading && _slots.isEmpty)
              const Text(
                'Nenhum horário disponível nesta consulta. Confira os horários de funcionamento e os profissionais cadastrados.',
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _slots
                  .map(
                    (slot) => ChoiceChip(
                      label: Text('${slot.label} · ${slot.professionalName}'),
                      selected: identical(_selected, slot),
                      onSelected: _loading
                          ? null
                          : (_) => setState(() => _selected = slot),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _selected == null || controller.busy
                  ? null
                  : () {
                      final slot = _selected!;
                      final parts = slot.label.split(':');
                      widget.draft.startsAt = slot.startsAt;
                      widget.draft.companyStartsAt = DateTime(
                        _day.year,
                        _day.month,
                        _day.day,
                        int.parse(parts[0]),
                        int.parse(parts[1]),
                      );
                      widget.draft.professionalId = slot.professionalId;
                      widget.draft.professionalName = slot.professionalName;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              BookingConfirmationScreen(draft: widget.draft),
                        ),
                      );
                    },
              child: const Text('Selecionar horário'),
            ),
            const SizedBox(height: 12),
            const Text(
              'A disponibilidade será conferida novamente ao confirmar. Alterações exigem conexão.',
            ),
          ],
        ),
      ),
    );
  }
}
