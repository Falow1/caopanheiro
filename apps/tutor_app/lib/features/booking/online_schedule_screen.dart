import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppScreenTips, AppTourTarget;
import '../../core/screen_tips.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppRadii, AppTextStyles;

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_widgets.dart';
import '../../state/app_scope.dart';
import '../../domain/repositories/tutor_session.dart';
import '../navigation/tutor_wide_layout.dart';
import 'booking_draft.dart';
import 'confirmation_screen.dart';
import 'transport_options_screen.dart';
import 'widgets/booking_frame.dart';

/// Days offered in the strip; other dates stay reachable through "Outra data".
const scheduleStripDays = 14;

class OnlineScheduleScreen extends StatefulWidget {
  const OnlineScheduleScreen({super.key, required this.draft, this.today});
  final BookingDraft draft;

  /// Test hook for the first strip day; defaults to the device date.
  final DateTime? today;
  @override
  State<OnlineScheduleScreen> createState() => _OnlineScheduleScreenState();
}

class _Professional {
  const _Professional(this.id, this.name);
  final String id;
  final String name;
}

/// One start time; several professionals may offer the same instant.
class _TimeOption {
  _TimeOption(this.label, this.startsAt);
  final String label;
  final DateTime startsAt;
  int get hour => int.parse(label.split(':').first);
}

class _OnlineScheduleScreenState extends State<OnlineScheduleScreen> {
  late final DateTime _today = _dateOnly(widget.today ?? DateTime.now());
  late DateTime _day = _today;

  /// Last day offered, by the strip's Outra data and by the open month.
  late final DateTime _lastDay = DateTime(
    _today.year + 2,
    _today.month,
    _today.day,
  );
  List<TutorSlot> _slots = [];
  String? _time;
  // null means any professional; the server picks one free at confirmation.
  _Professional? _professional;
  bool _loading = false;
  String? _error;
  int _request = 0;

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
  String get _date =>
      '${_day.year.toString().padLeft(4, '0')}-${_day.month.toString().padLeft(2, '0')}-${_day.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _time = null;
      _slots = [];
      _error = null;
    });
    try {
      final controller = AppScope.of(context);
      if (controller.companyId != widget.draft.companyId) {
        throw const FormatException('A empresa mudou. Reinicie o agendamento.');
      }
      final items = widget.draft.pets
          .map(
            (pet) => {
              'petId': pet.id,
              'serviceIds': widget.draft.selectedServices[pet.id]!
                  .map((service) => service.id)
                  .toList(),
            },
          )
          .toList();
      final slots = widget.draft.reschedule
          ? await controller.rescheduleSlots(
              _date,
              items,
              widget.draft.appointmentId,
            )
          : await controller.availableSlots(_date, items);
      if (mounted && request == _request) setState(() => _slots = slots);
    } catch (error) {
      if (mounted && request == _request) {
        setState(
          () => _error = error is FormatException
              ? error.message
              : 'Não foi possível consultar os horários. Atualize com conexão.',
        );
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _selectDay(DateTime day) async {
    if (_loading || day == _day) return;
    setState(() => _day = day);
    await _load();
  }

  Future<void> _pickDay() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: _today,
      lastDate: _lastDay,
      helpText: 'Escolher data',
      cancelText: 'Cancelar',
      confirmText: 'Escolher',
    );
    if (date == null || !mounted) return;
    await _selectDay(_dateOnly(date));
  }

  /// Professionals with free times on the day, plus the chosen one so the
  /// preference stays visible when that person has no time on another day.
  List<_Professional> get _professionals {
    final byId = <String, _Professional>{
      for (final slot in _slots)
        slot.professionalId: _Professional(
          slot.professionalId,
          slot.professionalName,
        ),
    };
    final chosen = _professional;
    if (chosen != null) byId.putIfAbsent(chosen.id, () => chosen);
    return byId.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  List<_TimeOption> get _times {
    final byLabel = <String, _TimeOption>{};
    for (final slot in _slots) {
      if (_professional != null && slot.professionalId != _professional!.id) {
        continue;
      }
      byLabel.putIfAbsent(
        slot.label,
        () => _TimeOption(slot.label, slot.startsAt),
      );
    }
    return byLabel.values.toList()..sort((a, b) => a.label.compareTo(b.label));
  }

  void _chooseProfessional(_Professional? professional) {
    if (_loading) return;
    setState(() {
      _professional = professional;
      if (!_times.any((time) => time.label == _time)) _time = null;
    });
  }

  void _continue() {
    final time = _times.where((item) => item.label == _time).firstOrNull;
    if (time == null) return;
    widget.draft.startsAt = time.startsAt;
    widget.draft.professionalId = _professional?.id;
    widget.draft.professionalName = _professional?.name;
    widget.draft.companyStartsAt = DateTime.parse('${_date}T${time.label}:00');
    // A reschedule keeps the transport rules of the team: no new quote. A
    // petshop without transport in the app has no transport step; while
    // unknown, the transport step reads the policy itself.
    final review =
        widget.draft.reschedule ||
        AppScope.of(context).transportOffered == false;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => review
            ? ConfirmationScreen(draft: widget.draft)
            : TransportOptionsScreen(draft: widget.draft),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AppScreenTips(
    screen: TipScreens.bookingSchedule,
    tips: tutorTips(context, TutorTips.bookingSchedule),
    ready: !_loading,
    child: _content(context),
  );

  Widget _content(BuildContext context) {
    final professionals = _professionals;
    final times = _times;
    final selected = times.where((item) => item.label == _time).firstOrNull;
    final wide = tutorWide(context);
    return BookingFrame(
      title: 'Escolher horário',
      step: 2,
      stepCount: bookingStepCount(context, reschedule: widget.draft.reschedule),
      actions: [
        // Pulling the page down needs a touch screen.
        if (wide)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TutorRefreshButton(onRefresh: _load, loading: _loading),
          ),
      ],
      onRefresh: _load,
      barNote: selected == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                '${formatWeekday(_day)}, ${formatShortDate(_day)} às ${selected.label} · ${_professional?.name ?? 'qualquer profissional'}',
                style: AppTextStyles.captionMuted,
              ),
            ),
      summary: BookingSummary(
        pets: widget.draft.pets,
        services: widget.draft.selectedServices,
        when: selected == null
            ? null
            : BookingSummary.day(_day, selected.label),
        professional: _professional?.name ?? 'Qualquer profissional',
        showProfessional: true,
      ),
      primary: FilledButton(
        onPressed: selected == null || _loading ? null : _continue,
        child: const Text('Continuar'),
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
          'Horários para ${widget.draft.totalDuration} min de atendimento. A disponibilidade será conferida novamente ao confirmar.',
        ),
        const SizedBox(height: 20),
        if (!wide) ...[
          AppTourTarget(
            id: TipTargets.scheduleDays,
            child: _DayStrip(
              first: _today,
              selected: _day,
              enabled: !_loading,
              onSelected: _selectDay,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppTourTarget(
              id: TipTargets.scheduleOtherDate,
              child: OutlinedButton.icon(
                onPressed: _loading ? null : _pickDay,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(
                  _day.difference(_today).inDays >= scheduleStripDays
                      ? 'Outra data · ${formatDate(_day)}'
                      : 'Outra data',
                ),
              ),
            ),
          ),
          ..._choices(professionals, times, top: true),
        ] else if (tutorTwoColumns(context))
          // The month at the left and the choices of the day beside it.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 300, child: _calendar()),
              const SizedBox(width: 28),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _choices(professionals, times, top: false),
                ),
              ),
            ],
          )
        else ...[
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: SizedBox(width: 340, child: _calendar()),
          ),
          ..._choices(professionals, times, top: true),
        ],
      ],
    );
  }

  /// The open month of wide windows, in place of the strip and Outra data.
  Widget _calendar() => AppTourTarget(
    id: TipTargets.scheduleDays,
    child: BookingCalendar(
      first: _today,
      last: _lastDay,
      selected: _day,
      enabled: !_loading,
      onSelected: _selectDay,
    ),
  );

  /// Professional and the free times of the day; [top] adds the space above
  /// them when they come under the days.
  List<Widget> _choices(
    List<_Professional> professionals,
    List<_TimeOption> times, {
    required bool top,
  }) => [
    if (professionals.length > 1) ...[
      if (top) const SizedBox(height: 24),
      const SectionHeader(title: 'Profissional'),
      AppTourTarget(
        id: TipTargets.scheduleProfessional,
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _Choice(
              label: 'Qualquer profissional',
              selected: _professional == null,
              onSelected: _loading ? null : () => _chooseProfessional(null),
            ),
            for (final professional in professionals)
              _Choice(
                label: professional.name,
                selected: _professional?.id == professional.id,
                onSelected: _loading
                    ? null
                    : () => _chooseProfessional(professional),
              ),
          ],
        ),
      ),
    ],
    if (top || professionals.length > 1) const SizedBox(height: 24),
    const SectionHeader(title: 'Horários disponíveis'),
    if (_loading)
      const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      )
    else if (_error != null)
      Text(_error!, style: const TextStyle(color: AppColors.danger))
    else if (times.isEmpty)
      Text(
        _professional != null && _slots.isNotEmpty
            ? '${_professional!.name} não tem horários livres neste dia. Escolha outro dia ou qualquer profissional.'
            : 'Nenhum horário disponível neste dia. Escolha outro dia.',
      )
    else
      for (final (title, from, to) in const [
        ('Manhã', 0, 12),
        ('Tarde', 12, 18),
        ('Noite', 18, 24),
      ])
        if (times.any((t) => t.hour >= from && t.hour < to)) ...[
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 10),
            child: Text(title, style: AppTextStyles.captionMuted),
          ),
          AppTourTarget(
            id: TipTargets.scheduleTimes,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final time in times.where(
                  (t) => t.hour >= from && t.hour < to,
                ))
                  _Choice(
                    label: time.label,
                    selected: time.label == _time,
                    onSelected: () => setState(() => _time = time.label),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
  ];
}

class _DayStrip extends StatefulWidget {
  const _DayStrip({
    required this.first,
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });
  final DateTime first;
  final DateTime selected;
  final bool enabled;
  final ValueChanged<DateTime> onSelected;

  @override
  State<_DayStrip> createState() => _DayStripState();
}

class _DayStripState extends State<_DayStrip> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScrollConfiguration(
    // Web does not drag horizontal lists with the mouse by default.
    behavior: ScrollConfiguration.of(
      context,
    ).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
    child: Scrollbar(
      controller: _controller,
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 12),
        child: _days(),
      ),
    ),
  );

  Widget _days() {
    final first = widget.first;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < scheduleStripDays; index++)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: _DayButton(
              day: DateTime(first.year, first.month, first.day + index),
              today: index == 0,
              selected:
                  DateTime(first.year, first.month, first.day + index) ==
                  widget.selected,
              onTap: widget.enabled
                  ? () => widget.onSelected(
                      DateTime(first.year, first.month, first.day + index),
                    )
                  : null,
            ),
          ),
      ],
    );
  }
}

class _DayButton extends StatelessWidget {
  const _DayButton({
    required this.day,
    required this.today,
    required this.selected,
    required this.onTap,
  });
  final DateTime day;
  final bool today;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : AppColors.ink;
    return Semantics(
      button: true,
      selected: selected,
      label:
          '${today ? 'Hoje, ' : ''}${formatWeekday(day)}, ${formatShortDate(day)}',
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.primary : AppColors.paper,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.r18,
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.line,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.r18,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 66, minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    today ? 'HOJE' : formatWeekday(day).toUpperCase(),
                    style: AppTextStyles.captionMuted.copyWith(
                      color: selected ? Colors.white70 : AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${day.day}',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: foreground),
                  ),
                  Text(
                    formatShortDate(day).split(' ').last,
                    style: AppTextStyles.captionMuted.copyWith(
                      color: selected ? Colors.white70 : AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onSelected,
  });
  final String label;
  final bool selected;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: Text(label),
    ),
    selected: selected,
    showCheckmark: false,
    onSelected: onSelected == null ? null : (_) => onSelected!(),
    selectedColor: AppColors.primary,
    labelStyle: TextStyle(
      color: selected ? Colors.white : AppColors.ink,
      fontWeight: FontWeight.w800,
    ),
    side: BorderSide(color: selected ? AppColors.primary : AppColors.line),
    shape: RoundedRectangleBorder(borderRadius: AppRadii.r14),
  );
}
