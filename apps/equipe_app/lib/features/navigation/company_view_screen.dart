import 'package:equipe_app/domain/policies/transport_review.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:caopanheiro_core/caopanheiro_core.dart'
    show LiveRefresh, LiveSignalPaths, NetworkException;
import '../../core/formatters.dart' as fmt;
import '../../core/team_layout.dart';
import '../../domain/models.dart';
import '../../domain/models/team_company.dart';
import '../../state/workforce_controller.dart';
import '../../state/workforce_scope.dart';
import '../agenda/appointment_detail_screen.dart';
import '../agenda/transport_management_screen.dart';
import '../agenda/transport_requests_screen.dart';
import '../agenda/transport_screen.dart';
import '../customers/customer_detail_screen.dart';
import '../customers/tutor_join_link_screen.dart';
import '../services/service_form_screen.dart';
import '../admin/professionals_screen.dart';
import '../admin/availability_screen.dart';
import '../admin/business_hours_screen.dart';
import '../admin/blocks_screen.dart';
import '../admin/workforce_members_screen.dart';
import '../../modules/professional/features/appointments/appointment_detail_screen.dart'
    as pro;
import '../../modules/driver/features/transports/transport_detail_screen.dart'
    as driver;

class CompanyViewScreen extends StatefulWidget {
  const CompanyViewScreen({
    super.key,
    required this.role,
    required this.resource,
    required this.title,
    this.destination,
    this.showBack = true,
    this.today = false,
    this.history = false,
    this.reviewOnly = false,
  });
  final TenantRole role;
  final String resource, title;
  final String? destination;
  final bool showBack, today, history, reviewOnly;
  @override
  State<CompanyViewScreen> createState() => _CompanyViewScreenState();
}

class _Page {
  _Page(this.company);
  final TeamCompany company;
  final List<Map<String, dynamic>> items = [];
  String? cursor, error;
  bool busy = false, loaded = false;
}

class _CompanyViewScreenState extends State<CompanyViewScreen>
    with WidgetsBindingObserver {
  WorkforceController? _scope;
  int _revision = -1, _generation = 0;
  bool _opening = false;
  List<_Page> _pages = [];

  /// Team signals of every petshop shown; a change reads its pages again.
  LiveRefresh? _live;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    ++_generation;
    _live?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = WorkforceScope.of(context);
    if (_scope != scope || _revision != scope.viewRevision) {
      _scope = scope;
      _revision = scope.viewRevision;
      unawaited(_refresh());
    }
  }

  Future<void> _refresh() async {
    final scope = _scope;
    if (scope == null ||
        !scope.allCompanies ||
        scope.function != widget.role ||
        _opening) {
      return;
    }
    final generation = ++_generation;
    _pages = scope.team.companies.map(_Page.new).toList();
    for (final page in _pages) {
      if (!page.company.user.availableRoles.contains(widget.role)) {
        page.error = 'Esta função não está disponível nesta empresa.';
      } else if (widget.resource == 'members' &&
          !page.company.user.isPrincipal) {
        page.error =
            'A administração de usuários é exclusiva do gestor principal desta empresa.';
      } else if (widget.resource == 'tutorLink' &&
          !page.company.user.canManage('CUSTOMERS')) {
        page.error = 'Seu acesso não inclui os clientes desta empresa.';
      } else {
        page.busy = true;
      }
    }
    if (mounted) setState(() {});
    _live ??= scope.team.followCompanies(() => unawaited(_liveRefresh()));
    _live?.watch(
      _pages
          .where((page) => page.busy)
          .map((p) => LiveSignalPaths.team(p.company.id)),
    );
    final queue = _pages.where((page) => page.busy).iterator;
    Future<void> worker() async {
      while (generation == _generation && queue.moveNext()) {
        await _load(queue.current, generation);
      }
    }

    await Future.wait(List.generate(4, (_) => worker()));
  }

  /// Live refresh: reads again the first page of each petshop already shown,
  /// without loading state; a failure keeps what is on screen.
  Future<void> _liveRefresh() async {
    final scope = _scope;
    if (scope == null || !mounted || _opening || !scope.allCompanies) return;
    final generation = _generation, revision = scope.viewRevision;
    for (final page in _pages.where((page) => page.loaded && !page.busy)) {
      try {
        final result = await scope.team.companyView(
          tenantId: page.company.id,
          role: widget.role,
          resource: widget.resource,
        );
        if (!mounted ||
            generation != _generation ||
            revision != scope.viewRevision ||
            page.busy) {
          return;
        }
        setState(() {
          page.items
            ..clear()
            ..addAll(result.items);
          page.cursor = result.nextCursor;
        });
      } catch (_) {}
    }
  }

  Future<void> _load(_Page page, int generation, {bool more = false}) async {
    final scope = _scope!, revision = scope.viewRevision;
    page.busy = true;
    page.error = null;
    if (mounted) setState(() {});
    try {
      final result = await scope.team.companyView(
        tenantId: page.company.id,
        role: widget.role,
        resource: widget.resource,
        cursor: more ? page.cursor : null,
      );
      if (!mounted ||
          generation != _generation ||
          revision != scope.viewRevision ||
          !scope.allCompanies ||
          scope.function != widget.role) {
        return;
      }
      if (!more) page.items.clear();
      final known = page.items.map((item) => item['id']).toSet();
      page.items.addAll(result.items.where((item) => known.add(item['id'])));
      if (more &&
          result.nextCursor == page.cursor &&
          result.nextCursor != null) {
        throw const FormatException(
          'A próxima página não avançou. Atualize a consulta.',
        );
      }
      page.cursor = result.nextCursor;
      page.loaded = true;
    } catch (error) {
      if (!mounted ||
          generation != _generation ||
          revision != scope.viewRevision) {
        return;
      }
      // Revoked/failed pages must not keep an older authorized snapshot visible.
      page.items.clear();
      page.loaded = false;
      page.cursor = null;
      page.error = error is NetworkException
          ? 'Conecte-se para consultar todas as empresas.'
          : error is FormatException
          ? error.message
          : 'Não foi possível consultar esta empresa. Tente novamente.';
    } finally {
      if (mounted &&
          generation == _generation &&
          revision == scope.viewRevision) {
        setState(() => page.busy = false);
      }
    }
  }

  bool get _administrative => [
    'professionals',
    'blocks',
    'scheduling',
    'members',
    'transportPolicy',
    'transportRequests',
    'tutorLink',
  ].contains(widget.resource);
  bool _canOpen(_Page page) {
    if (widget.resource == 'tutorLink') {
      return widget.role == TenantRole.manager &&
          page.company.user.canManage('CUSTOMERS');
    }
    if (widget.resource == 'services') {
      return widget.role == TenantRole.manager &&
          page.company.user.canManage('SERVICES');
    }
    if (widget.resource == 'scheduling' ||
        widget.resource == 'transportPolicy') {
      return widget.role == TenantRole.manager &&
          page.company.user.canManage('SETTINGS');
    }
    if (widget.resource == 'blocks') {
      return page.company.user.asFunction(widget.role).canManageBlocks;
    }
    if (widget.destination == 'availability') {
      return page.company.user.canManage('PROFESSIONALS');
    }
    return true;
  }

  String _week(Object? value) {
    if (value is! Map) return 'Horários não configurados';
    const days = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    String clock(Object? minute) {
      if (minute is! num) return minute?.toString() ?? '?';
      final number = minute.toInt();
      return '${(number ~/ 60).toString().padLeft(2, '0')}:${(number % 60).toString().padLeft(2, '0')}';
    }

    return List.generate(7, (index) {
      final periods = value[(index + 1).toString()] as List? ?? [];
      return '${days[index]}: ${periods.isEmpty ? 'Fechado' : periods.map((period) => '${clock((period as Map)['start'])}–${clock(period['end'])}').join(', ')}';
    }).join('\n');
  }

  Future<void> _open(_Page page, Map<String, dynamic>? item) async {
    if (!_canOpen(page)) return;
    if (_opening || _scope!.busy || _scope!.hasUnconfirmed) return;
    final scope = _scope!,
        nav = Navigator.of(context),
        messenger = ScaffoldMessenger.of(context);
    final role = widget.role,
        resource = widget.resource,
        destination = widget.destination;
    setState(() => _opening = true);
    try {
      if (!await scope.openCompany(page.company.id, role)) {
        throw FormatException(scope.error ?? 'Empresa indisponível.');
      }
      final revision = scope.viewRevision;
      if ([TenantRole.manager, TenantRole.attendant].contains(role)) {
        if (resource == 'customers') {
          // The detail reads upcoming appointments from the origin's agenda.
          if (!await scope.team.refreshAgenda() ||
              !await scope.team.refreshCustomers()) {
            throw const FormatException(
              'Atualize a empresa com conexão antes de abrir os dados.',
            );
          }
        } else if ([
          'appointments',
          'professionals',
          'blocks',
        ].contains(resource)) {
          await scope.team.refreshAgenda();
        }
      }
      if (!nav.mounted ||
          !scope.allCompanies ||
          scope.viewRevision != revision ||
          scope.function != role ||
          scope.team.company?.id != page.company.id) {
        return;
      }
      if (scope.team.readOnly ||
          scope.team.error != null &&
              ['appointments', 'customers'].contains(resource)) {
        throw const FormatException(
          'Atualize a empresa com conexão antes de abrir os dados.',
        );
      }
      final id = item?['id'] as String?;
      Widget screen;
      if (resource == 'appointments') {
        screen = role == TenantRole.professional
            ? pro.AppointmentDetailScreen(appointmentId: id!)
            : AppointmentDetailScreen(appointmentId: id!);
      } else if (resource == 'transports') {
        screen = role == TenantRole.driver
            ? driver.TransportDetailScreen(transportId: id!)
            : TransportManagementScreen(
                appointmentId: item?['appointmentId'] as String?,
              );
      } else if (resource == 'customers') {
        screen = CustomerDetailScreen(customerId: id!);
      } else if (resource == 'services') {
        final services = scope.team.services.where(
          (service) => service.id == id,
        );
        if (services.isEmpty) {
          throw const FormatException(
            'Serviço indisponível. Atualize a consulta.',
          );
        }
        screen = ServiceFormScreen(service: services.first);
      } else if (resource == 'members') {
        screen = WorkforceMembersScreen(management: destination != 'workforce');
      } else if (resource == 'transportPolicy') {
        screen = const TransportScreen();
      } else if (resource == 'transportRequests') {
        screen = const TransportRequestsScreen();
      } else if (resource == 'scheduling') {
        screen = const BusinessHoursScreen();
      } else if (resource == 'blocks') {
        screen = const BlocksScreen();
      } else if (resource == 'tutorLink') {
        screen = const TutorJoinLinkScreen();
      } else {
        screen = destination == 'availability'
            ? const AvailabilityScreen()
            : const ProfessionalsScreen();
      }
      await nav.push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.storefront_outlined),
                        const SizedBox(width: 8),
                        Expanded(child: Text(page.company.name)),
                      ],
                    ),
                  ),
                  Expanded(child: screen),
                ],
              ),
            ),
          ),
        ),
      );
    } catch (error) {
      if (nav.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              error is FormatException
                  ? error.message
                  : 'Não foi possível abrir esta empresa.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _opening = false);
        await _refresh();
      }
    }
  }

  DateTime? _date(Map<String, dynamic> item) {
    // Appointment and transport civil time belong to the company, not the
    // device timezone.
    final local = item['localStartsAt'] ?? item['localScheduledAt'];
    if (local is String) return DateTime.tryParse(local);
    final value = item['startsAt'] ?? item['scheduledAt'];
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      return widget.resource == 'transports' ? parsed?.toLocal() : parsed;
    }
    if (value is Map) {
      final seconds = value['_seconds'] ?? value['seconds'];
      if (seconds is num) {
        return DateTime.fromMillisecondsSinceEpoch((seconds * 1000).round());
      }
    }
    return null;
  }

  bool _visible(Map<String, dynamic> item) {
    if (widget.reviewOnly) {
      final when = _date(item);
      return when != null &&
          transportNeedsReview(when, item['status']?.toString() ?? '');
    }
    if (widget.resource == 'members' && widget.destination == 'workforce') {
      return !(item['roles'] as List? ?? []).contains('MANAGER') &&
          !(item['invitedRoles'] as List? ?? []).contains('MANAGER');
    }
    if (widget.resource == 'members') {
      return (item['roles'] as List? ?? []).contains('MANAGER') ||
          (item['invitedRoles'] as List? ?? []).contains('MANAGER');
    }
    if (widget.history) {
      return ['DELIVERED', 'CANCELLED'].contains(item['status']);
    }
    if (widget.role == TenantRole.driver &&
        ['DELIVERED', 'CANCELLED'].contains(item['status'])) {
      return false;
    }
    if (widget.today) {
      final when = _date(item), now = DateTime.now();
      return when != null &&
          ((when.year == now.year &&
                  when.month == now.month &&
                  when.day == now.day) ||
              widget.role == TenantRole.driver && when.isBefore(now));
    }
    return true;
  }

  String _title(Map<String, dynamic> item) {
    if (widget.resource == 'appointments') {
      final pet = item['pet'];
      if (pet is Map) return pet['name']?.toString() ?? 'Atendimento';
      return (item['customer'] as Map?)?['name']?.toString() ?? 'Agendamento';
    }
    if (widget.resource == 'transports') {
      return (item['pets'] as List? ?? [])
          .map((pet) => (pet as Map)['name'])
          .join(', ');
    }
    if (widget.resource == 'scheduling') return 'Horários da empresa';
    if (widget.resource == 'transportPolicy') return 'Transporte da empresa';
    if (widget.resource == 'transportRequests') return 'Pedido de transporte';
    if (widget.resource == 'tutorLink') return 'Link de convite';
    return (item['name'] ??
            item['reason'] ??
            item['title'] ??
            'Bloqueio de agenda')
        .toString();
  }

  String _details(Map<String, dynamic> item) {
    if (widget.resource == 'services') {
      return [
            item['description'],
            fmt.money(((item['priceCents'] as num?) ?? 0) / 100),
            '${item['durationMinutes']} min',
            item['active'] == true ? 'Ativo' : 'Inativo',
          ]
          .where((value) => value != null && value.toString().isNotEmpty)
          .join(' · ');
    }
    if (widget.resource == 'transportPolicy') {
      return item['enabled'] == true ? 'Ativo' : 'Desativado';
    }
    if (widget.resource == 'tutorLink') {
      // The company view never creates the link: it is born when its area opens.
      final active = item['active'];
      final pending = (item['pendingReturns'] as num?)?.toInt() ?? 0;
      return [
        active == null
            ? 'Será criado ao abrir'
            : active == true
            ? 'Ativo'
            : 'Desativado',
        if (pending > 0)
          pending == 1 ? '1 pedido de retorno' : '$pending pedidos de retorno',
      ].join(' · ');
    }
    if (widget.resource == 'members' && widget.destination == 'workforce') {
      return (item['roles'] as List? ?? [])
          .map(
            (role) =>
                const {
                  'ATTENDANT': 'Atendente',
                  'PROFESSIONAL': 'Profissional',
                  'DRIVER': 'Entregador',
                }[role] ??
                role,
          )
          .join(' · ');
    }
    if (widget.resource == 'scheduling') {
      return 'Fuso horário: ${item['timeZone'] ?? 'Não configurado'}\n${_week(item['days'])}';
    }
    if (widget.resource == 'professionals') {
      return '${item['specialty'] ?? ''} · ${item['active'] == true ? 'Ativo' : 'Inativo'}${widget.destination == 'availability' ? '\n${_week(item['availability'])}' : ''}';
    }
    if (widget.resource == 'members') {
      return item['principal'] == true
          ? 'Gestor principal'
          : item['invitationPending'] == true
          ? 'Convite pendente'
          : 'Gestão · ${item['active'] == true ? 'Ativo' : 'Inativo'}';
    }
    if (widget.resource == 'customers') {
      return '${(item['pets'] as List? ?? []).length} pets';
    }
    final when = _date(item);
    final status = (item['status'] ?? '').toString();
    const labels = {
      'REQUESTED': 'Solicitado',
      'CONFIRMED': 'Confirmado',
      'PET_RECEIVED': 'Pet recebido',
      'IN_PROGRESS': 'Em andamento',
      'COMPLETED': 'Concluído',
      'CANCELLED': 'Cancelado',
      'NO_SHOW': 'Não compareceu',
      'PENDING': 'Pendente',
      'ASSIGNED': 'Atribuído',
      'STARTED': 'Iniciado',
      'COLLECTED': 'Coletado',
      'DELIVERED': 'Entregue',
      'GOING_TO_ORIGIN': 'A caminho da origem',
      'PET_COLLECTED': 'Pet coletado',
      'IN_TRANSIT': 'Em transporte',
      'ACCEPTED': 'Aceito',
      'REJECTED': 'Recusado',
      'READY': 'Pronto',
      'WAITING': 'Aguardando',
    };
    return [
      if (when != null) '${fmt.date(when)} ${fmt.time(when)}',
      if (widget.resource == 'transports' &&
          when != null &&
          transportNeedsReview(when, status))
        'Atrasado — precisa de revisão',
      labels[status] ?? status,
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final scope = WorkforceScope.of(context);
    if (!scope.allCompanies || scope.function != widget.role) {
      return const SizedBox.shrink();
    }
    return Scaffold(
      appBar: widget.showBack ? AppBar(title: Text(widget.title)) : null,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: TeamLayout.page,
          children: [
            if (!widget.showBack)
              Text(
                widget.title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            const SizedBox(height: 8),
            const Text('Todas as empresas · Dados identificados por empresa'),
            const SizedBox(height: 16),
            if (widget.resource == 'professionals' &&
                widget.destination == null &&
                scope.team.companies.any((company) => company.user.isPrincipal))
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CompanyViewScreen(
                      role: widget.role,
                      resource: 'members',
                      title: 'Equipe e funções',
                      destination: 'workforce',
                    ),
                  ),
                ),
                icon: const Icon(Icons.badge_outlined),
                label: const Text('Equipe e funções'),
              ),
            for (final page in _pages) ...[
              Text(
                page.company.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (page.busy)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: LinearProgressIndicator(),
                ),
              if (page.error != null) ...[
                Text(page.error!),
                if (page.company.user.availableRoles.contains(widget.role) &&
                    (widget.resource != 'members' ||
                        page.company.user.isPrincipal) &&
                    (widget.resource != 'tutorLink' ||
                        page.company.user.canManage('CUSTOMERS')))
                  OutlinedButton(
                    onPressed: () => _load(page, _generation),
                    child: const Text('Tentar novamente'),
                  ),
              ],
              if (page.loaded && page.items.where(_visible).isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Nenhum registro nesta parte da consulta.'),
                ),
              for (final item
                  in (page.items.where(_visible).toList()..sort(
                    (a, b) =>
                        widget.resource == 'appointments' ||
                            widget.resource == 'transports'
                        ? (_date(a) ?? DateTime(1970)).compareTo(
                            _date(b) ?? DateTime(1970),
                          )
                        : _title(a).compareTo(_title(b)),
                  )))
                Card(
                  key: ValueKey('${page.company.id}:${item['id']}'),
                  child: ListTile(
                    title: Text(_title(item)),
                    subtitle: Text('${page.company.name}\n${_details(item)}'),
                    trailing: _canOpen(page)
                        ? const Icon(Icons.chevron_right)
                        : null,
                    onTap:
                        _opening ||
                            scope.busy ||
                            scope.hasUnconfirmed ||
                            !_canOpen(page)
                        ? null
                        : () => _open(page, item),
                  ),
                ),
              if (page.cursor != null && !page.busy && page.error == null)
                OutlinedButton(
                  onPressed: () => _load(page, _generation, more: true),
                  child: Text('Carregar mais de ${page.company.name}'),
                ),
              if (_administrative &&
                  page.loaded &&
                  page.error == null &&
                  _canOpen(page))
                OutlinedButton(
                  onPressed: _opening || scope.busy || scope.hasUnconfirmed
                      ? null
                      : () => _open(page, null),
                  child: Text('Abrir em ${page.company.name}'),
                ),
              const SizedBox(height: 24),
            ],
            if (_pages.isEmpty)
              const Text('Nenhuma empresa disponível para esta consulta.'),
          ],
        ),
      ),
    );
  }
}
