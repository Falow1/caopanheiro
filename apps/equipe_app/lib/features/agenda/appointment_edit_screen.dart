import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';
import '../../state/app_scope.dart';
import '../booking/booking_draft.dart';
import '../booking/integrated_schedule_screen.dart';

class AppointmentEditScreen extends StatefulWidget {
  const AppointmentEditScreen({super.key, required this.appointmentId});
  final String appointmentId;

  @override
  State<AppointmentEditScreen> createState() => _AppointmentEditScreenState();
}

class _AppointmentEditScreenState extends State<AppointmentEditScreen> {
  Appointment? _original;
  late DateTime _startsAt;
  String? _professional;
  late final TextEditingController _notes;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_original == null) {
      _original = AppScope.of(
        context,
      ).appointments.firstWhere((item) => item.id == widget.appointmentId);
      _startsAt = _original!.startsAt;
      _professional = _original!.professional;
      _notes = TextEditingController(text: _original!.notes);
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _startsAt,
      firstDate: DateTime(2026),
      lastDate: DateTime(2027),
    );
    if (value != null) {
      setState(() {
        _startsAt = DateTime(
          value.year,
          value.month,
          value.day,
          _startsAt.hour,
          _startsAt.minute,
        );
      });
    }
  }

  Future<void> _pickTime() async {
    final value = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startsAt),
    );
    if (value != null) {
      setState(() {
        _startsAt = DateTime(
          _startsAt.year,
          _startsAt.month,
          _startsAt.day,
          value.hour,
          value.minute,
        );
      });
    }
  }

  Future<void> _save() async {
    final updated = Appointment(
      id: _original!.id,
      customer: _original!.customer,
      startsAt: _startsAt,
      status: _original!.status,
      items: _original!.items,
      professional: _professional,
      notes: _notes.text.trim(),
      tutorNotes: _original!.tutorNotes,
    );
    final saved = await AppScope.of(context).saveAppointment(updated);
    if (mounted && saved) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    if (controller.catalogOnly) {
      return FormScaffold(
        title: 'Editar agendamento',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_original!.customer.name),
            Text(_original!.petNames),
            const SizedBox(height: 16),
            TextField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Observações'),
            ),
            if (controller.error != null) Text(controller.error!),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: controller.busy || controller.catalogOffline
                  ? null
                  : () async {
                      final saved = await controller.updateAppointmentNotes(
                        widget.appointmentId,
                        _notes.text.trim(),
                      );
                      if (saved && context.mounted) Navigator.pop(context);
                    },
              child: const Text('Salvar observações'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: controller.busy || controller.catalogOffline
                  ? null
                  : () {
                      final draft =
                          BookingDraft(
                              customer: _original!.customer,
                              appointmentId: _original!.id,
                              editing: true,
                            )
                            ..notes = _notes.text.trim()
                            ..startsAt = _original!.startsAt
                            ..companyStartsAt = _original!.displayStartsAt
                            ..professionalId = _original!.professionalId;
                      for (final item in _original!.items) {
                        draft.pets.add(item.pet);
                        draft.services[item.pet.id] = item.services.toSet();
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              IntegratedScheduleScreen(draft: draft),
                        ),
                      );
                    },
              child: const Text('Remarcar atendimento'),
            ),
          ],
        ),
      );
    }
    return FormScaffold(
      title: 'Editar agendamento',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _original!.customer.name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(_original!.petNames),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(date(_startsAt)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.schedule_rounded),
                  label: Text(time(_startsAt)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _professional,
            decoration: const InputDecoration(labelText: 'Profissional'),
            items: controller.professionals
                .where((item) => item.active)
                .map(
                  (item) => DropdownMenuItem(
                    value: item.name,
                    child: Text(item.name),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _professional = value),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _notes,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Observações'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: controller.busy ? null : _save,
            child: Text(controller.busy ? 'Salvando...' : 'Salvar alterações'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }
}
