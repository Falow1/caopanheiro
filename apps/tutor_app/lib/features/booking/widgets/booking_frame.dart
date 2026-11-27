import 'dart:math' as math;

import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show
        AppDimensions,
        AppPetIcon,
        AppRadii,
        AppRefreshBody,
        AppTextStyles,
        AppTourTarget;
import 'package:flutter/material.dart';

import '../../../core/screen_tips.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/models/pet.dart';
import '../../../domain/models/service.dart';
import '../../../state/app_scope.dart';
import '../../navigation/tutor_shell_scope.dart';
import '../../navigation/tutor_wide_layout.dart';
import 'step_indicator.dart';

/// Width of the summary beside the steps on wide windows.
const bookingSummaryWidth = 320.0;

/// Steps of a booking: five when the petshop offers transport in the app
/// (Pets, Serviços, Horário, Transporte, Revisão), four otherwise and in a
/// reschedule, which keeps the transport of the appointment.
int bookingStepCount(BuildContext context, {bool reschedule = false}) =>
    !reschedule && AppScope.of(context).transportOffered == true ? 5 : 4;

/// Where the phone keeps the main button of a step, as before the desktop
/// design: a bar under the list, the bottom sheet of the Scaffold, or inside
/// the list.
enum BookingPhoneBar { bottom, sheet, inline }

/// Frame of the booking steps.
///
/// - Phone (under 900): title, steps, the list and the bar of the step, as
///   before; the list keeps to the column of 620.
/// - Wide window with two columns: the steps with their names over the list
///   and, at the right, the [summary] with the [primary] button and [back].
/// - Narrower wide window: one column, with the summary folded above the
///   button.
///
/// The list is always the same widget in the same place, so a window that
/// crosses the breakpoint keeps the scroll, and the state of the step stays
/// in its screen.
class BookingFrame extends StatefulWidget {
  const BookingFrame({
    super.key,
    required this.title,
    required this.children,
    this.step,
    this.stepCount = 4,
    this.stepsTip = false,
    this.actions = const [],
    this.summary,
    this.summaryTip,
    this.primary,
    this.primaryTip,
    this.back,
    this.barBack = false,
    this.barNote,
    this.phoneBar = BookingPhoneBar.bottom,
    this.phoneTop = 8,
    this.phoneBottom = 24,
    this.sheetBottom = 18,
    this.onRefresh,
  });

  /// Marks the summary beside the steps, for tests.
  static const panelKey = ValueKey('booking.summary.panel');

  final String title;
  final List<Widget> children;

  /// Current step, from 0; null shows no steps.
  final int? step;

  /// Steps of the booking, four or five (see [bookingStepCount]).
  final int stepCount;

  /// Whether the steps carry the target of the "Etapas" tip.
  final bool stepsTip;
  final List<Widget> actions;

  /// What was chosen so far; null shows no summary (and no bar).
  final BookingSummary? summary;

  /// Tip target carried by the summary beside the steps, if any. Each step
  /// uses its own: the screens below in the stack keep theirs.
  final String? summaryTip;

  /// Main button of the step; null leaves it to the list.
  final Widget? primary;

  /// Tip target of [primary], in every layout.
  final String? primaryTip;

  /// Shown under [primary] in the summary, and in the bars when [barBack].
  final Widget? back;
  final bool barBack;

  /// Above [primary] in the phone bar.
  final Widget? barNote;
  final BookingPhoneBar phoneBar;
  final double phoneTop;
  final double phoneBottom;

  /// Bottom padding of the phone bar when it is the bottom sheet.
  final double sheetBottom;

  /// Pulling the list down calls it.
  final Future<void> Function()? onRefresh;

  @override
  State<BookingFrame> createState() => _BookingFrameState();
}

class _BookingFrameState extends State<BookingFrame> {
  /// Whether the folded summary of narrower wide windows is open.
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final wide = tutorWide(context);
    final summary = widget.summary;
    final two = wide && summary != null && tutorTwoColumns(context);
    final content = tutorContentWidth(context);
    // Wide: the page of 1080 in the middle of the content area. Otherwise
    // the column of 620, with at least 20 at each side.
    final side = math.max(
      32.0,
      (content - AppDimensions.tutorDesktopPageWidth) / 2,
    );
    final gutter = math.max(20.0, (content - AppDimensions.tutorPageWidth) / 2);
    final plain = wide && summary == null;
    final EdgeInsets padding;
    if (two) {
      padding = EdgeInsets.fromLTRB(side, 8, 32, 32);
    } else if (plain) {
      padding = EdgeInsets.fromLTRB(side, 24, side, 32);
    } else if (wide) {
      padding = EdgeInsets.fromLTRB(gutter, 8, gutter, 24);
    } else {
      padding = EdgeInsets.fromLTRB(
        gutter,
        widget.phoneTop,
        gutter,
        widget.phoneBottom,
      );
    }
    final edge = two || plain ? side : gutter;
    Widget list = ListView(padding: padding, children: widget.children);
    if (widget.onRefresh case final refresh?) {
      list = AppRefreshBody(onRefresh: refresh, child: list);
    }
    final step = widget.step;
    final sheet =
        !wide && widget.phoneBar == BookingPhoneBar.sheet && _hasBar(wide);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), actions: widget.actions),
      body: Column(
        children: [
          if (step != null)
            Padding(
              padding: EdgeInsets.fromLTRB(edge, 4, edge, 18),
              child: widget.stepsTip
                  ? AppTourTarget(
                      id: TipTargets.steps,
                      child: StepIndicator(
                        current: step,
                        total: widget.stepCount,
                      ),
                    )
                  : StepIndicator(current: step, total: widget.stepCount),
            ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: list),
                if (two) _panel(context, summary, side),
              ],
            ),
          ),
          if (!two && !sheet && _hasBar(wide))
            wide ? _foldedBar(context, gutter) : _phoneBar(gutter, 20),
        ],
      ),
      bottomSheet: sheet ? _phoneBar(gutter, widget.sheetBottom) : null,
    );
  }

  bool _hasBar(bool wide) =>
      widget.primary != null &&
      (wide
          ? widget.summary != null
          : widget.phoneBar != BookingPhoneBar.inline);

  Widget _primary() {
    final primary = widget.primary!;
    final tip = widget.primaryTip;
    return tip == null ? primary : AppTourTarget(id: tip, child: primary);
  }

  List<Widget> _back({required bool always}) {
    final back = widget.back;
    if (back == null || !(always || widget.barBack)) return const [];
    return [Align(child: back)];
  }

  BoxDecoration get _barDecoration => const BoxDecoration(
    color: AppColors.paper,
    border: Border(top: BorderSide(color: AppColors.line)),
  );

  /// The bar of the phone, as each step had it.
  Widget _phoneBar(double gutter, double bottom) => Container(
    padding: EdgeInsets.fromLTRB(gutter, 14, gutter, bottom),
    decoration: _barDecoration,
    child: SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [?widget.barNote, _primary(), ..._back(always: false)],
      ),
    ),
  );

  /// Narrower wide window: one line of the summary, which opens above the
  /// button, then the button.
  Widget _foldedBar(BuildContext context, double gutter) {
    final summary = widget.summary!;
    final height = MediaQuery.sizeOf(context).height;
    return Container(
      padding: EdgeInsets.fromLTRB(gutter, 10, gutter, 18),
      decoration: _barDecoration,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_open)
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: height * 0.3),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 6, bottom: 6),
                  child: summary,
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    summary.folded,
                    style: AppTextStyles.captionMuted,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _open = !_open),
                  icon: Icon(
                    _open
                        ? Icons.expand_more_rounded
                        : Icons.expand_less_rounded,
                  ),
                  label: Text(_open ? 'Ocultar resumo' : 'Ver resumo'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _primary(),
            ..._back(always: false),
          ],
        ),
      ),
    );
  }

  /// The summary at the right, with the button of the step under it.
  Widget _panel(BuildContext context, BookingSummary summary, double side) {
    final panel = Container(
      key: BookingFrame.panelKey,
      width: bookingSummaryWidth,
      margin: EdgeInsets.fromLTRB(0, 8, side, 24),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: AppRadii.r22,
        border: Border.all(color: AppColors.line),
      ),
      child: FocusTraversalGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
              child: Text(
                'Resumo',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
                child: summary,
              ),
            ),
            if (widget.primary != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [_primary(), ..._back(always: true)],
                ),
              ),
          ],
        ),
      ),
    );
    final tip = widget.summaryTip;
    return tip == null ? panel : AppTourTarget(id: tip, child: panel);
  }
}

/// What the person chose so far in the booking.
class BookingSummary extends StatelessWidget {
  const BookingSummary({
    super.key,
    required this.pets,
    this.services,
    this.when,
    this.professional,
    this.showProfessional = false,
    this.transport,
    this.transportCents = 0,
    this.petProfessionals,
    this.reservedMinutes,
  });

  /// "Ana · 08:00–09:00" under each pet, once the professionals of a booking
  /// with several pets are known; null hides it.
  final Map<String, String>? petProfessionals;

  /// Real time of the booking (the busiest professional), shown beside the
  /// summed time of the services when it differs; null before the time.
  final int? reservedMinutes;

  final List<Pet> pets;

  /// Services of each pet; null before the services step.
  final Map<String, Set<PetService>>? services;

  /// Day and time, as "ter, 17 nov às 10:30"; null while not chosen.
  final String? when;
  final String? professional;

  /// The online Tutor lets the person choose the professional.
  final bool showProfessional;

  /// Transport line; null hides it.
  final String? transport;
  final int transportCents;

  /// "ter, 17 nov às 10:30".
  static String day(DateTime day, String time) =>
      '${formatWeekday(day)}, ${formatShortDate(day)} às $time';

  /// The transport line of a quote, as "Coleta e retorno · R$ 25,00".
  static String transportLine(Map<String, dynamic> quote) {
    final legs = [
      for (final leg in quote['legs'] as List)
        leg['type'] == 'PICKUP' ? 'coleta' : 'retorno',
    ];
    final names = legs.join(' e ');
    final label = names.isEmpty
        ? 'Transporte'
        : '${names[0].toUpperCase()}${names.substring(1)}';
    return '$label · ${formatMoney((quote['totalCents'] as num) / 100)}';
  }

  Iterable<PetService> get _all =>
      services?.values.expand((items) => items) ?? const [];
  double get total =>
      _all.fold<double>(0, (sum, service) => sum + service.price) +
      transportCents / 100;
  int get _minutes =>
      _all.fold(0, (sum, service) => sum + service.durationMinutes);

  /// One line for the folded summary of narrower wide windows.
  String get folded {
    if (services == null) {
      return pets.isEmpty
          ? 'Nenhum pet escolhido'
          : pets.map((pet) => pet.name).join(', ');
    }
    final count = _all.length;
    return [
      '$count ${count == 1 ? 'serviço' : 'serviços'}',
      '$_minutes min',
      ?when,
      formatMoney(total),
    ].join(' · ');
  }

  Widget _line(IconData icon, String label, String? value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.captionMuted),
              const SizedBox(height: 2),
              Text(
                value ?? 'A escolher',
                style: value == null
                    ? AppTextStyles.captionMuted
                    : AppTextStyles.strong,
              ),
            ],
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final services = this.services;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (pets.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Escolha um ou mais pets.',
              style: AppTextStyles.captionMuted,
            ),
          ),
        for (final pet in pets) ...[
          Row(
            children: [
              AppPetIcon(icon: pet.breedIcon, size: 28),
              const SizedBox(width: 8),
              Expanded(child: Text(pet.name, style: text.titleMedium)),
            ],
          ),
          const SizedBox(height: 6),
          if (petProfessionals?[pet.id] case final line?)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.person_outline_rounded,
                    size: 17,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: Text(line, style: AppTextStyles.strong)),
                ],
              ),
            ),
          if (services != null) ...[
            if (services[pet.id]?.isEmpty ?? true)
              const Text(
                'Escolha os serviços',
                style: AppTextStyles.captionMuted,
              )
            else
              for (final service in services[pet.id]!)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          '${service.name} · ${service.durationMinutes} min',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(formatMoney(service.price)),
                    ],
                  ),
                ),
          ],
          const SizedBox(height: 12),
        ],
        const Divider(height: 16),
        const SizedBox(height: 8),
        _line(Icons.calendar_today_outlined, 'Dia e horário', when),
        if (showProfessional)
          _line(Icons.person_outline_rounded, 'Profissional', professional),
        if (transport case final transport?)
          _line(Icons.local_shipping_outlined, 'Transporte', transport),
        if (services != null) ...[
          const Divider(height: 16),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  reservedMinutes == null || reservedMinutes == _minutes
                      ? 'Tempo estimado'
                      : 'Duração somada dos serviços',
                  style: AppTextStyles.captionMuted,
                ),
              ),
              Text('$_minutes min', style: AppTextStyles.strong),
            ],
          ),
          // Pets with different professionals are done at the same time.
          if (reservedMinutes case final reserved?
              when reserved != _minutes) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Tempo previsto da reserva',
                    style: AppTextStyles.captionMuted,
                  ),
                ),
                Text('$reserved min', style: AppTextStyles.strong),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text('Total', style: text.titleMedium)),
              Text(formatMoney(total), style: text.titleLarge),
            ],
          ),
        ],
      ],
    );
  }
}

/// A choice of the booking that can be marked, as a service or a transport
/// option: a card with the check at the left, mint when marked.
class BookingCheckCard extends StatelessWidget {
  const BookingCheckCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.subtitleMaxLines,
    this.trailing,
  });
  final String title;
  final String subtitle;
  final bool selected;

  /// Null while the choice is locked.
  final VoidCallback? onTap;
  final int? subtitleMaxLines;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final onTap = this.onTap;
    return Material(
      color: selected ? AppColors.mint : AppColors.paper,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.r18,
        side: BorderSide(color: selected ? AppColors.primary : AppColors.line),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.r18,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Checkbox(
                value: selected,
                onChanged: onTap == null ? null : (_) => onTap(),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Column(
                  // Centered with the check when the card is stretched.
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: subtitleMaxLines,
                      overflow: subtitleMaxLines == null
                          ? null
                          : TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (trailing case final trailing?) ...[
                const SizedBox(width: 8),
                trailing,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Cards side by side on wide windows, two per row when they fit; one under
/// the other on the phone, as before, [gap] apart.
class BookingGrid extends StatelessWidget {
  const BookingGrid({
    super.key,
    required this.children,
    this.gap = 12,
    this.sameHeight = false,
  });
  final List<Widget> children;
  final double gap;

  /// Whether the two cards of a row take the height of the taller one.
  final bool sameHeight;

  @override
  Widget build(BuildContext context) {
    if (!tutorWide(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final child in children)
            Padding(
              padding: EdgeInsets.only(bottom: gap),
              child: child,
            ),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final two = constraints.maxWidth >= 560;
        final width = two
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        if (two && sameHeight) {
          return Padding(
            padding: EdgeInsets.only(bottom: gap),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i += 2)
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: children[i]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: i + 1 < children.length
                                ? children[i + 1]
                                : const SizedBox(),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        }
        return Padding(
          padding: EdgeInsets.only(bottom: gap),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final child in children)
                SizedBox(width: width, child: child),
            ],
          ),
        );
      },
    );
  }
}

const _monthNames = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

/// One month open, in Portuguese and starting on Sunday, for wide windows.
/// Days before [first] or after [last] cannot be chosen.
class BookingCalendar extends StatefulWidget {
  const BookingCalendar({
    super.key,
    required this.first,
    required this.last,
    required this.selected,
    required this.onSelected,
    this.enabled = true,
  });
  final DateTime first;
  final DateTime last;
  final DateTime selected;
  final ValueChanged<DateTime> onSelected;
  final bool enabled;

  @override
  State<BookingCalendar> createState() => _BookingCalendarState();
}

class _BookingCalendarState extends State<BookingCalendar> {
  late DateTime _month = _monthOf(widget.selected);

  static DateTime _monthOf(DateTime day) => DateTime(day.year, day.month);

  @override
  void didUpdateWidget(BookingCalendar old) {
    super.didUpdateWidget(old);
    // A day chosen elsewhere shows its month.
    if (widget.selected != old.selected) _month = _monthOf(widget.selected);
  }

  bool get _canGoBack => _month.isAfter(_monthOf(widget.first));
  bool get _canGoOn => _month.isBefore(_monthOf(widget.last));

  void _go(int months) =>
      setState(() => _month = DateTime(_month.year, _month.month + months));

  Widget _day(BuildContext context, DateTime day) {
    final open =
        widget.enabled &&
        !day.isBefore(widget.first) &&
        !day.isAfter(widget.last);
    final today = DateUtils.isSameDay(day, widget.first);
    final selected = DateUtils.isSameDay(day, widget.selected);
    final past = day.isBefore(widget.first) || day.isAfter(widget.last);
    return Semantics(
      button: true,
      enabled: open,
      selected: selected,
      label:
          '${today ? 'Hoje, ' : ''}${formatWeekday(day)}, ${day.day} de '
          '${_monthNames[day.month - 1].toLowerCase()}',
      excludeSemantics: true,
      child: Center(
        child: InkWell(
          onTap: open && !selected ? () => widget.onSelected(day) : null,
          customBorder: const CircleBorder(),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? AppColors.primary : null,
              border: today && !selected
                  ? Border.all(color: AppColors.primary, width: 1.5)
                  : null,
            ),
            child: Text(
              '${day.day}',
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : past
                    ? AppColors.muted.withValues(alpha: 0.5)
                    : AppColors.ink,
                fontWeight: selected || today
                    ? FontWeight.w800
                    : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lead = _month.weekday % 7;
    final days = DateUtils.getDaysInMonth(_month.year, _month.month);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: AppRadii.r22,
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Mês anterior',
                onPressed: _canGoBack ? () => _go(-1) : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  '${_monthNames[_month.month - 1]} de ${_month.year}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Próximo mês',
                onPressed: _canGoOn ? () => _go(1) : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ExcludeSemantics(
            child: Row(
              children: [
                for (final name in const ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'])
                  Expanded(
                    child: Center(
                      child: Text(name, style: AppTextStyles.captionMuted),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 2,
            children: [
              for (var i = 0; i < lead; i++) const SizedBox(),
              for (var d = 1; d <= days; d++)
                _day(context, DateTime(_month.year, _month.month, d)),
            ],
          ),
        ],
      ),
    );
  }
}
