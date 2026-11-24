import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppRadii, AppTextStyles;

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import 'booking_draft.dart';
import '../../state/app_scope.dart';
import 'integrated_schedule_screen.dart';
import 'booking_confirmation_screen.dart';

class ScheduleSelectionScreen extends StatefulWidget {
  const ScheduleSelectionScreen({super.key, required this.draft});
  final BookingDraft draft;
  @override
  State<ScheduleSelectionScreen> createState() =>
      _ScheduleSelectionScreenState();
}

class _ScheduleSelectionScreenState extends State<ScheduleSelectionScreen> {
  DateTime _day = DateTime(2026, 9, 21);
  String? _selected;
  final _times = const ['08:00', '10:30', '14:00', '16:30'];

  @override
  Widget build(BuildContext context) {
    if (AppScope.of(context).catalogOnly) {
      return IntegratedScheduleScreen(draft: widget.draft);
    }
    final days = List.generate(6, (index) => DateTime(2026, 9, 21 + index));
    return Scaffold(
      appBar: AppBar(title: const Text('Escolher horário')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                const Text(
                  '4 de 5 · Horário',
                  style: AppTextStyles.primaryStrong,
                ),
                const SizedBox(height: 14),
                Text(
                  'Quando será?',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 5),
                Text(
                  'Horários válidos para ${widget.draft.duration} minutos de atendimento.',
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 84,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: days.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 9),
                    itemBuilder: (_, index) {
                      final day = days[index];
                      final selected = day.day == _day.day;
                      return InkWell(
                        onTap: () => setState(() {
                          _day = day;
                          _selected = null;
                        }),
                        borderRadius: AppRadii.r17,
                        child: Container(
                          width: 67,
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary
                                : AppColors.paper,
                            borderRadius: AppRadii.r17,
                            border: Border.all(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.line,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                friendlyDate(day).substring(0, 3).toUpperCase(),
                                style: TextStyle(
                                  color: selected
                                      ? Colors.white70
                                      : AppColors.muted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                day.day.toString(),
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: selected
                                          ? Colors.white
                                          : AppColors.ink,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Horários disponíveis',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _times.map((value) {
                    final selected = value == _selected;
                    return ChoiceChip(
                      selected: selected,
                      showCheckmark: false,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : AppColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 7,
                        ),
                        child: Text(value),
                      ),
                      onSelected: (_) => setState(() => _selected = value),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Horários ocupados, bloqueados ou fora da disponibilidade já foram removidos.',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 13, 20, 20),
            decoration: const BoxDecoration(
              color: AppColors.paper,
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: SafeArea(
              top: false,
              child: FilledButton(
                onPressed: _selected == null
                    ? null
                    : () {
                        final parts = _selected!.split(':');
                        widget.draft.startsAt = DateTime(
                          _day.year,
                          _day.month,
                          _day.day,
                          int.parse(parts[0]),
                          int.parse(parts[1]),
                        );
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
            ),
          ),
        ],
      ),
    );
  }
}
