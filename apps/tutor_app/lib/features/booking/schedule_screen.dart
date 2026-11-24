import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppRadii, AppTextStyles;

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_widgets.dart';
import 'booking_draft.dart';
import '../../state/app_scope.dart';
import 'online_schedule_screen.dart';
import 'confirmation_screen.dart';
import 'widgets/booking_frame.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key, required this.draft});
  final BookingDraft draft;
  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late DateTime _selectedDay = DateTime(2026, 9, 21);
  TimeOfDay? _time;
  final _times = const [
    TimeOfDay(hour: 8, minute: 0),
    TimeOfDay(hour: 10, minute: 30),
    TimeOfDay(hour: 14, minute: 0),
    TimeOfDay(hour: 16, minute: 30),
  ];

  void _continue() {
    widget.draft.startsAt = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
      _time!.hour,
      _time!.minute,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConfirmationScreen(draft: widget.draft),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (AppScope.of(context).integrated) {
      return OnlineScheduleScreen(draft: widget.draft);
    }
    final days = List.generate(7, (index) => DateTime(2026, 9, 21 + index));
    final time = _time;
    return BookingFrame(
      title: 'Escolher horário',
      step: 2,
      summary: BookingSummary(
        pets: widget.draft.pets,
        services: widget.draft.selectedServices,
        when: time == null
            ? null
            : BookingSummary.day(
                _selectedDay,
                formatTime(DateTime(2026, 1, 1, time.hour, time.minute)),
              ),
      ),
      primary: FilledButton(
        onPressed: _time == null ? null : _continue,
        child: const Text('Selecionar horário'),
      ),
      back: TextButton(
        onPressed: () => Navigator.maybePop(context),
        child: const Text('Voltar'),
      ),
      children: [
        Text(
          'Qual o melhor dia?',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Mostrando horários que comportam ${widget.draft.totalDuration} min de atendimento.',
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 86,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, index) {
              final day = days[index];
              final selected = day.day == _selectedDay.day;
              return InkWell(
                onTap: () => setState(() {
                  _selectedDay = day;
                  _time = null;
                }),
                borderRadius: AppRadii.r18,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 66,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : AppColors.paper,
                    borderRadius: AppRadii.r18,
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.line,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        formatWeekday(day).toUpperCase(),
                        style: TextStyle(
                          color: selected ? Colors.white70 : AppColors.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${day.day}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: selected ? Colors.white : AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 30),
        const SectionHeader(title: 'Horários disponíveis'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _times.map((time) {
            final selected = _time == time;
            return ChoiceChip(
              label: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                child: Text(time.format(context)),
              ),
              selected: selected,
              showCheckmark: false,
              onSelected: (_) => setState(() => _time = time),
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: selected ? Colors.white : AppColors.ink,
                fontWeight: FontWeight.w800,
              ),
              side: BorderSide(
                color: selected ? AppColors.primary : AppColors.line,
              ),
              shape: RoundedRectangleBorder(borderRadius: AppRadii.r14),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        const Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 18, color: AppColors.muted),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Horários ocupados ou incompatíveis não aparecem na lista.',
                style: AppTextStyles.caption,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
