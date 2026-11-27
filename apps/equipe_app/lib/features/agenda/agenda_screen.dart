import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppScreenTips, AppTourTarget;
import '../../core/screen_tips.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppRadii, AppTextStyles;

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../core/role_notice_bell.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';
import '../../state/app_scope.dart';
import 'appointment_detail_screen.dart';

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key, required this.onNew});
  final VoidCallback onNew;
  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  DateTime _day = DateTime(2026, 9, 18);
  AppointmentStatus? _filter;

  bool _initialized = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized && AppScope.of(context).catalogOnly) {
      _initialized = true;
      _day = DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) => AppScreenTips(
    screen: TipScreens.agenda,
    tips: TeamTips.agenda,
    ready: !AppScope.of(context).busy,
    child: _content(context),
  );

  Widget _content(BuildContext context) {
    final controller = AppScope.of(context);
    if (controller.user == null) return const SizedBox.shrink();
    final all = AppScope.of(context).appointments;
    final items =
        all
            .where(
              (item) =>
                  item.displayStartsAt.year == _day.year &&
                  item.displayStartsAt.month == _day.month &&
                  item.displayStartsAt.day == _day.day &&
                  (_filter == null || item.status == _filter),
            )
            .toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (controller.catalogOnly) ...[
              if (controller.agendaError != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(controller.agendaError!),
                ),
              if (controller.busy) const LinearProgressIndicator(),
            ],
            Padding(
              padding: TeamLayout.header,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Agenda',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        Text(friendlyDate(_day)),
                      ],
                    ),
                  ),
                  RoleNoticeBell(
                    source: controller.teamNotices,
                    tenantId: controller.company?.id,
                    refreshKey: (
                      controller.agendaUpdatedAt,
                      controller.liveRevision,
                    ),
                  ),
                  AppTourTarget(
                    id: TipTargets.agendaDay,
                    child: IconButton.filledTonal(
                      tooltip: 'Trocar dia',
                      onPressed: _pickDay,
                      icon: const Icon(Icons.calendar_month_rounded),
                    ),
                  ),
                ],
              ),
            ),
            AppTourTarget(
              id: TipTargets.agendaFilters,
              child: SizedBox(
                height: 48,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  children: [
                    _Filter(
                      label: 'Todos',
                      selected: _filter == null,
                      onTap: () => setState(() => _filter = null),
                    ),
                    ...[
                      AppointmentStatus.confirmed,
                      AppointmentStatus.petReceived,
                      AppointmentStatus.inProgress,
                      AppointmentStatus.completed,
                    ].map(
                      (status) => _Filter(
                        label: status.label,
                        selected: _filter == status,
                        onTap: () => setState(() => _filter = status),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.event_available_rounded,
                            size: 52,
                            color: AppColors.primary,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Agenda livre',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 5),
                          const Text('Nenhum atendimento para este filtro.'),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: TeamLayout.list,
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, index) => AppTourTarget(
                        id: TipTargets.agendaCard,
                        child: _AppointmentCard(
                          item: items[index],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AppointmentDetailScreen(
                                appointmentId: items[index].id,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton:
          controller.catalogOffline ||
              controller.user?.canManage('APPOINTMENTS') != true
          ? null
          : AppTourTarget(
              id: TipTargets.agendaNew,
              child: FloatingActionButton.extended(
                heroTag: 'team-new-appointment',
                onPressed: widget.onNew,
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Novo agendamento'),
              ),
            ),
    );
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (picked != null) setState(() => _day = picked);
  }
}

class _Filter extends StatelessWidget {
  const _Filter({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
    ),
  );
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.item, required this.onTap});
  final Appointment item;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: AppRadii.r20,
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 54,
              child: Text(
                time(item.displayStartsAt),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: AppColors.primary),
              ),
            ),
            Container(
              width: 3,
              height: 78,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: AppRadii.r9,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item.petNames} — ${item.customer.name}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.items
                        .expand((entry) => entry.services)
                        .map((service) => service.name)
                        .join(' + '),
                  ),
                  if (item.professionals case final names?)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(names, style: AppTextStyles.caption),
                    ),
                  const SizedBox(height: 9),
                  StatusBadge(status: item.status),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    ),
  );
}
