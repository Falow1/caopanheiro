import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppScreenTips, AppTourTarget;
import '../../../../core/screen_tips.dart';
import 'package:equipe_app/core/role_notice_bell.dart';

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';
import '../../state/app_scope.dart';
import '../appointments/appointment_detail_screen.dart';

enum AgendaFilter { all, pending, completed }

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  DateTime? _date;
  DateTime get _selectedDate => _date ?? DateTime(2026, 9, 20);
  AgendaFilter _filter = AgendaFilter.all;

  @override
  Widget build(BuildContext context) => AppScreenTips(
    screen: TipScreens.proAgenda,
    tips: TeamTips.proAgenda,
    ready: !AppScope.of(context).busy,
    child: _content(context),
  );

  Widget _content(BuildContext context) {
    if (_date == null && AppScope.of(context).integrated) {
      _date = DateTime.now();
    }
    final items = AppScope.of(context).appointments.where((item) {
      final sameDay =
          item.displayStartsAt.year == _selectedDate.year &&
          item.displayStartsAt.month == _selectedDate.month &&
          item.displayStartsAt.day == _selectedDate.day;
      if (!sameDay) return false;
      return switch (_filter) {
        AgendaFilter.all => true,
        AgendaFilter.pending => const {
          AppointmentStatus.requested,
          AppointmentStatus.confirmed,
          AppointmentStatus.petReceived,
          AppointmentStatus.inProgress,
        }.contains(item.status),
        AgendaFilter.completed => item.status == AppointmentStatus.completed,
      };
    }).toList()..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
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
                        Text(formatFriendlyDate(_selectedDate)),
                      ],
                    ),
                  ),
                  RoleNoticeBell(
                    source: AppScope.of(context).noticesSource,
                    tenantId: AppScope.of(context).companyId,
                    refreshKey: (
                      AppScope.of(context).updatedAt,
                      AppScope.of(context).liveRevision,
                    ),
                  ),
                  AppTourTarget(
                    id: TipTargets.proDay,
                    child: IconButton.filledTonal(
                      tooltip: 'Selecionar data',
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_month_rounded),
                    ),
                  ),
                ],
              ),
            ),
            AppTourTarget(
              id: TipTargets.proFilters,
              child: SizedBox(
                height: 48,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  children: [
                    _FilterChip(
                      label: 'Todos',
                      selected: _filter == AgendaFilter.all,
                      onTap: () => setState(() => _filter = AgendaFilter.all),
                    ),
                    _FilterChip(
                      label: 'Pendentes',
                      selected: _filter == AgendaFilter.pending,
                      onTap: () =>
                          setState(() => _filter = AgendaFilter.pending),
                    ),
                    _FilterChip(
                      label: 'Finalizados',
                      selected: _filter == AgendaFilter.completed,
                      onTap: () =>
                          setState(() => _filter = AgendaFilter.completed),
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
                            'Nenhum atendimento',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 5),
                          const Text('Selecione outra data ou filtro.'),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 11),
                      itemBuilder: (_, index) => AppTourTarget(
                        id: TipTargets.proAgendaCard,
                        child: AppointmentCard(
                          appointment: items[index],
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
    );
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2026),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (value != null) {
      setState(() => _date = value);
    }
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onTap(),
      ),
    );
  }
}
