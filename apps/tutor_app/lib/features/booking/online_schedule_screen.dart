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

/// How the tutor wants the professionals: the server distributes the pets
/// ([any]), one professional does them all ([one]) or one per pet ([perPet]).
enum _Mode { any, one, perPet }

/// One start time; several professionals may offer the same instant.
class _TimeOption {
  _TimeOption(this.label, this.slot);
  final String label;
  final TutorSlot slot;
  DateTime get startsAt => slot.startsAt;
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
  _Mode _mode = _Mode.any;
  // The professional of every pet in [_Mode.one].
  _Professional? _professional;
  // The professional of each pet in [_Mode.perPet], at the chosen time.
  Map<String, String> _assignments = {};
  bool _loading = false;
  String? _error;
  int _request = 0;

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
  String get _date =>
      '${_day.year.toString().padLeft(4, '0')}-${_day.month.toString().padLeft(2, '0')}-${_day.day.toString().padLeft(2, '0')}';

  BookingDraft get _draft => widget.draft;
  bool get _severalPets => _draft.pets.length > 1;
  int get _total => _draft.totalDuration;

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
      if (controller.companyId != _draft.companyId) {
        throw const FormatException('A empresa mudou. Reinicie o agendamento.');
      }
      final items = _draft.pets
          .map(
            (pet) => {
              'petId': pet.id,
              'serviceIds': _draft.selectedServices[pet.id]!
                  .map((service) => service.id)
                  .toList(),
            },
          )
          .toList();
      // SPECIFIC brings the automatic distribution of each time and who is
      // free to be chosen, so every choice of this page reads one answer.
      final slots = _draft.reschedule
          ? await controller.rescheduleSlots(
              _date,
              items,
              _draft.appointmentId,
              distribution: Distribution.specific,
            )
          : await controller.availableSlots(
              _date,
              items,
              distribution: Distribution.specific,
            );
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

  /// Free professionals of a slot, with their free minutes. A slot without
  /// the list (one professional per slot) offers its own professional.
  List<SlotProfessional> _free(TutorSlot slot) => slot.professionals.isNotEmpty
      ? slot.professionals
      : [SlotProfessional(slot.professionalId, slot.professionalName, _total)];

  /// Professionals free on the day, plus the chosen one so the preference
  /// stays visible when that person has no time on another day.
  List<_Professional> get _professionals {
    final byId = <String, _Professional>{
      for (final slot in _slots)
        for (final value in _free(slot))
          value.id: _Professional(value.id, value.name),
    };
    final chosen = _professional;
    if (chosen != null) byId.putIfAbsent(chosen.id, () => chosen);
    return byId.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Whether [id] has time for every pet, one after the other, at [slot].
  bool _takesAll(TutorSlot slot, String id) =>
      _free(slot).any((value) => value.id == id && value.freeMinutes >= _total);

  List<_TimeOption> get _times {
    final byLabel = <String, _TimeOption>{};
    for (final slot in _slots) {
      if (_mode == _Mode.one && !_takesAll(slot, _professional!.id)) continue;
      byLabel.putIfAbsent(slot.label, () => _TimeOption(slot.label, slot));
    }
    return byLabel.values.toList()..sort((a, b) => a.label.compareTo(b.label));
  }

  _TimeOption? get _selected =>
      _times.where((item) => item.label == _time).firstOrNull;

  void _chooseMode(_Mode mode, [_Professional? professional]) {
    if (_loading) return;
    setState(() {
      _mode = mode;
      _professional = professional;
      if (_selected == null) _time = null;
      _prefill();
    });
  }

  void _chooseTime(String label) => setState(() {
    _time = label;
    _prefill();
  });

  /// The choice per pet at a new time: the previous choice when it still
  /// fits, otherwise the distribution the server proposed.
  void _prefill() {
    final slot = _selected?.slot;
    if (_mode != _Mode.perPet || slot == null) return;
    final keep = _draft.pets.every(
      (pet) => _options(slot, pet.id).any((p) => p.id == _assignments[pet.id]),
    );
    if (keep && _overloaded(slot, _assignments).isEmpty) return;
    final automatic = {
      for (final row in slot.assignments) row.petId: row.professionalId,
    };
    _assignments = {
      for (final pet in _draft.pets)
        pet.id: automatic[pet.id] ?? slot.professionalId,
    };
  }

  /// Professionals that can do this pet at [slot]: free for its minutes.
  List<SlotProfessional> _options(TutorSlot slot, String petId) {
    final minutes = _draft.petMinutes(petId);
    return _free(slot).where((value) => value.freeMinutes >= minutes).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Professionals of [assignments] without time for their pets at [slot].
  List<SlotProfessional> _overloaded(
    TutorSlot slot,
    Map<String, String> assignments,
  ) {
    final loads = <String, int>{};
    for (final pet in _draft.pets) {
      final id = assignments[pet.id];
      if (id != null) loads[id] = (loads[id] ?? 0) + _draft.petMinutes(pet.id);
    }
    return [
      for (final value in _free(slot))
        if ((loads[value.id] ?? 0) > value.freeMinutes) value,
      for (final id in loads.keys)
        if (!_free(slot).any((value) => value.id == id))
          SlotProfessional(id, 'Profissional', 0),
    ];
  }

  /// Who does each pet at [slot] in the current mode: the server's proposal
  /// in [_Mode.any]; otherwise the pets of each professional in a row.
  List<SlotAssignment> _plan(TutorSlot slot) {
    if (_mode == _Mode.any) {
      if (slot.assignments.isNotEmpty) return slot.assignments;
      return _sequence(slot, {
        for (final pet in _draft.pets) pet.id: slot.professionalId,
      });
    }
    final chosen = _mode == _Mode.one
        ? {for (final pet in _draft.pets) pet.id: _professional!.id}
        : _assignments;
    return _sequence(slot, chosen);
  }

  List<SlotAssignment> _sequence(TutorSlot slot, Map<String, String> chosen) {
    final names = {for (final value in _free(slot)) value.id: value.name};
    final next = <String, DateTime>{};
    return [
      for (final pet in _draft.pets)
        if (chosen[pet.id] case final id?)
          () {
            final from = next[id] ?? slot.startsAt;
            final to = from.add(Duration(minutes: _draft.petMinutes(pet.id)));
            next[id] = to;
            return SlotAssignment(
              petId: pet.id,
              professionalId: id,
              professionalName: names[id] ?? _professional?.name ?? '',
              startsAt: from,
              endsAt: to,
            );
          }(),
    ];
  }

  int _minutesOf(TutorSlot slot, List<SlotAssignment> plan) => plan.isEmpty
      ? _total
      : plan
            .map((row) => row.endsAt.difference(slot.startsAt).inMinutes)
            .reduce((a, b) => a > b ? a : b);

  /// Why the choice per pet cannot be confirmed; null when it fits.
  String? _problem(TutorSlot slot) {
    if (_mode != _Mode.perPet) return null;
    if (_draft.pets.any((pet) => _assignments[pet.id] == null)) {
      return 'Escolha o profissional de cada pet.';
    }
    final busy = _overloaded(slot, _assignments);
    if (busy.isEmpty) return null;
    final first = busy.first;
    final pets = _draft.pets
        .where((pet) => _assignments[pet.id] == first.id)
        .map((pet) => pet.name)
        .toList();
    final minutes = _draft.pets
        .where((pet) => _assignments[pet.id] == first.id)
        .fold(0, (sum, pet) => sum + _draft.petMinutes(pet.id));
    return '${first.name} não tem tempo para ${_names(pets)} neste horário: '
        'são $minutes min de serviços e há ${first.freeMinutes} min livres. '
        'Escolha profissionais diferentes ou troque o horário.';
  }

  static String _names(List<String> names) => names.length < 2
      ? names.join()
      : '${names.sublist(0, names.length - 1).join(', ')} e ${names.last}';

  String _label(_TimeOption? selected) {
    if (_mode == _Mode.any) return 'Qualquer profissional';
    if (_mode == _Mode.one) return _professional!.name;
    final slot = selected?.slot;
    if (slot == null) return 'Escolha por pet';
    return {for (final row in _plan(slot)) row.professionalName}.join(', ');
  }

  void _continue() {
    final selected = _selected;
    if (selected == null || _problem(selected.slot) != null) return;
    final slot = selected.slot, plan = _plan(slot);
    final single = {for (final row in plan) row.professionalId};
    _draft
      ..startsAt = selected.startsAt
      ..companyStartsAt = DateTime.parse('${_date}T${selected.label}:00')
      ..distribution = _mode == _Mode.any
          ? Distribution.any
          : Distribution.specific
      ..assignments = _mode == _Mode.any
          ? {}
          : {for (final row in plan) row.petId: row.professionalId}
      ..plan = plan
      ..scheduleMinutes = _minutesOf(slot, plan)
      ..professionalId = _mode != _Mode.any && single.length == 1
          ? single.single
          : null
      ..professionalName = _mode != _Mode.any && single.length == 1
          ? plan.first.professionalName
          : null;
    // A reschedule keeps the transport rules of the team: no new quote. A
    // petshop without transport in the app has no transport step; while
    // unknown, the transport step reads the policy itself.
    final review =
        _draft.reschedule || AppScope.of(context).transportOffered == false;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => review
            ? ConfirmationScreen(draft: _draft)
            : TransportOptionsScreen(draft: _draft),
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
    final selected = _selected;
    final wide = tutorWide(context);
    final plan = selected == null ? null : _plan(selected.slot);
    final problem = selected == null ? null : _problem(selected.slot);
    return BookingFrame(
      title: 'Escolher horário',
      step: 2,
      stepCount: bookingStepCount(context, reschedule: _draft.reschedule),
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
                '${formatWeekday(_day)}, ${formatShortDate(_day)} às ${selected.label} · ${_mode == _Mode.any ? 'qualquer profissional' : _label(selected)}',
                style: AppTextStyles.captionMuted,
              ),
            ),
      summary: BookingSummary(
        pets: _draft.pets,
        services: _draft.selectedServices,
        when: selected == null
            ? null
            : BookingSummary.day(_day, selected.label),
        professional: _label(selected),
        showProfessional: true,
        petProfessionals: plan == null || !_severalPets
            ? null
            : _petLines(selected!, plan),
        reservedMinutes: selected == null
            ? null
            : _minutesOf(selected.slot, plan!),
      ),
      primary: FilledButton(
        onPressed: selected == null || _loading || problem != null
            ? null
            : _continue,
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
          _severalPets
              ? 'Os serviços somam $_total min. Com profissionais diferentes, os pets são atendidos ao mesmo tempo e a reserva fica mais curta. A disponibilidade será conferida novamente ao confirmar.'
              : 'Horários para $_total min de atendimento. A disponibilidade será conferida novamente ao confirmar.',
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

  /// "Ana · 08:00–09:00" per pet, on the company clock of the chosen day.
  Map<String, String> _petLines(
    _TimeOption selected,
    List<SlotAssignment> plan,
  ) {
    String clock(DateTime value) {
      final local = DateTime.parse(
        '${_date}T${selected.label}:00',
      ).add(value.difference(selected.startsAt));
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }

    return {
      for (final row in plan)
        row.petId:
            '${row.professionalName} · ${clock(row.startsAt)}–${clock(row.endsAt)}',
    };
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
  }) {
    final selected = _selected;
    return [
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
                selected: _mode == _Mode.any,
                onSelected: _loading ? null : () => _chooseMode(_Mode.any),
              ),
              for (final professional in professionals)
                _Choice(
                  label: professional.name,
                  selected:
                      _mode == _Mode.one &&
                      _professional?.id == professional.id,
                  onSelected: _loading
                      ? null
                      : () => _chooseMode(_Mode.one, professional),
                ),
              if (_severalPets)
                _Choice(
                  label: 'Escolher por pet',
                  selected: _mode == _Mode.perPet,
                  onSelected: _loading ? null : () => _chooseMode(_Mode.perPet),
                ),
            ],
          ),
        ),
        if (_severalPets) ...[
          const SizedBox(height: 10),
          Text(switch (_mode) {
            _Mode.any =>
              'A equipe distribui os pets entre os profissionais livres no horário.',
            _Mode.one =>
              '${_professional!.name} atende todos os pets, um depois do outro. Só aparecem os horários com tempo para todos.',
            _Mode.perPet =>
              'Escolha o horário e, depois, o profissional de cada pet.',
          }, style: AppTextStyles.captionMuted),
        ],
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
          _mode == _Mode.one && _slots.isNotEmpty
              ? _severalPets
                    ? '${_professional!.name} não tem tempo para todos os pets neste dia. Escolha outro dia, Escolher por pet ou qualquer profissional.'
                    : '${_professional!.name} não tem horários livres neste dia. Escolha outro dia ou qualquer profissional.'
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
                      onSelected: () => _chooseTime(time.label),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
      if (!_loading && _error == null && selected != null && _severalPets)
        AppTourTarget(
          id: TipTargets.schedulePets,
          child: _mode == _Mode.perPet
              ? _perPet(selected)
              : _distribution(selected),
        ),
    ];
  }

  /// Who does each pet at the chosen time, in [_Mode.any] and [_Mode.one].
  Widget _distribution(_TimeOption selected) {
    final plan = _plan(selected.slot), lines = _petLines(selected, plan);
    final minutes = _minutesOf(selected.slot, plan);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        const SectionHeader(title: 'Quem atende cada pet'),
        for (final pet in _draft.pets)
          _PetLine(name: pet.name, detail: lines[pet.id] ?? ''),
        const SizedBox(height: 6),
        Text(_reservedText(minutes), style: AppTextStyles.captionMuted),
      ],
    );
  }

  String _reservedText(int minutes) => minutes == _total
      ? 'Tempo previsto da reserva: $minutes min.'
      : 'Tempo previsto da reserva: $minutes min, com pets atendidos ao mesmo tempo (os serviços somam $_total min).';

  /// The choice of the professional of each pet, at the chosen time.
  Widget _perPet(_TimeOption selected) {
    final slot = selected.slot;
    final everyone = _free(slot).where((p) => p.freeMinutes >= _total).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final problem = _problem(slot);
    final plan = _plan(slot), lines = _petLines(selected, plan);
    // Times of the day when one professional has time for every pet.
    final single = [
      for (final time in _times)
        if (_free(time.slot).any((p) => p.freeMinutes >= _total)) time,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        const SectionHeader(title: 'Profissional de cada pet'),
        if (everyone.isNotEmpty) ...[
          const Text('Mesmo profissional para todos os pets:'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final professional in everyone)
                _Choice(
                  label: professional.name,
                  selected: _draft.pets.every(
                    (pet) => _assignments[pet.id] == professional.id,
                  ),
                  onSelected: () => setState(
                    () => _assignments = {
                      for (final pet in _draft.pets) pet.id: professional.id,
                    },
                  ),
                ),
            ],
          ),
        ] else ...[
          Text(
            'Neste horário, nenhum profissional tem tempo para todos os pets: escolha profissionais diferentes.${single.isEmpty ? '' : ' Para um só profissional, troque o horário:'}',
            style: const TextStyle(color: AppColors.warning),
          ),
          if (single.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final time in single)
                  _Choice(
                    label: time.label,
                    selected: false,
                    onSelected: () => _chooseTime(time.label),
                  ),
              ],
            ),
          ],
        ],
        const SizedBox(height: 14),
        for (final pet in _draft.pets) ...[
          Text(
            '${pet.name} · ${_draft.petMinutes(pet.id)} min',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final professional in _options(slot, pet.id))
                _Choice(
                  label: professional.name,
                  selected: _assignments[pet.id] == professional.id,
                  onSelected: () => setState(
                    () => _assignments = {
                      ..._assignments,
                      pet.id: professional.id,
                    },
                  ),
                ),
            ],
          ),
          if (problem == null && lines[pet.id] != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(lines[pet.id]!, style: AppTextStyles.captionMuted),
            ),
          const SizedBox(height: 14),
        ],
        if (problem != null)
          Semantics(
            liveRegion: true,
            child: Text(
              problem,
              style: const TextStyle(color: AppColors.danger),
            ),
          )
        else
          Text(
            _reservedText(_minutesOf(slot, plan)),
            style: AppTextStyles.captionMuted,
          ),
      ],
    );
  }
}

/// A pet and who does it, as "Ana · 08:00–09:00".
class _PetLine extends StatelessWidget {
  const _PetLine({required this.name, required this.detail});
  final String name;
  final String detail;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.pets_rounded, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: name, style: AppTextStyles.strong),
                TextSpan(text: ' · $detail'),
              ],
            ),
          ),
        ),
      ],
    ),
  );
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
