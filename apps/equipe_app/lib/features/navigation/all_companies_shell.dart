import '../agenda/transport_review_notice.dart';
import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppButtonStyles;
import '../../core/widgets.dart';
import '../../domain/models.dart';
import '../../state/workforce_scope.dart';
import '../more/team_profile_card.dart';
import '../more/more_menu_tile.dart';
import '../more/workforce_actions.dart';
import '../more/confirm_sign_out.dart';
import 'company_view_screen.dart';

class AllCompaniesShell extends StatefulWidget {
  const AllCompaniesShell({super.key});
  @override
  State<AllCompaniesShell> createState() => _AllCompaniesShellState();
}

class _AllCompaniesShellState extends State<AllCompaniesShell> {
  int? _index;
  @override
  Widget build(BuildContext context) {
    final scope = WorkforceScope.of(context),
        role = WorkforceScope.of(context).function!;
    final tabs = switch (role) {
      // Same icons as each role's own shell.
      TenantRole.professional => const [
        ('Hoje', 'appointments', Icons.today_outlined, Icons.today_rounded),
        (
          'Agenda',
          'appointments',
          Icons.calendar_month_outlined,
          Icons.calendar_month_rounded,
        ),
      ],
      TenantRole.driver => const [
        ('Hoje', 'transports', Icons.today_outlined, Icons.today_rounded),
        (
          'Transportes',
          'transports',
          Icons.route_outlined,
          Icons.route_rounded,
        ),
        (
          'Histórico',
          'transports',
          Icons.history_outlined,
          Icons.history_rounded,
        ),
      ],
      _ => const [
        (
          'Agenda',
          'appointments',
          Icons.calendar_today_outlined,
          Icons.calendar_today_rounded,
        ),
        (
          'Clientes',
          'customers',
          Icons.people_outline_rounded,
          Icons.people_rounded,
        ),
        (
          'Serviços',
          'services',
          Icons.content_cut_outlined,
          Icons.content_cut_rounded,
        ),
      ],
    };
    final last = role == TenantRole.manager ? 'Mais' : 'Perfil';
    final index =
        (_index ?? (scope.allTabIndex < 0 ? tabs.length : scope.allTabIndex))
            .clamp(0, tabs.length);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if ([TenantRole.manager, TenantRole.attendant].contains(role))
              TransportReviewNotice(allCompanies: true, role: role),
            Expanded(
              child: index == tabs.length
                  ? _AllProfile(role: role)
                  : CompanyViewScreen(
                      key: ValueKey('$role-$index'),
                      role: role,
                      title: tabs[index].$1,
                      resource: tabs[index].$2,
                      showBack: false,
                      today:
                          index == 0 &&
                          [
                            TenantRole.professional,
                            TenantRole.driver,
                          ].contains(role),
                      history: role == TenantRole.driver && index == 2,
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: TeamNavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) {
          scope.allTabIndex = value;
          setState(() => _index = value);
        },
        destinations: [
          for (final tab in tabs)
            NavigationDestination(
              icon: Icon(tab.$3),
              selectedIcon: Icon(tab.$4),
              label: tab.$1,
            ),
          NavigationDestination(
            icon: Icon(
              role == TenantRole.manager
                  ? Icons.grid_view_outlined
                  : Icons.person_outline_rounded,
            ),
            selectedIcon: Icon(
              role == TenantRole.manager
                  ? Icons.grid_view_rounded
                  : Icons.person_rounded,
            ),
            label: last,
          ),
        ],
      ),
    );
  }
}

class _AllProfile extends StatelessWidget {
  const _AllProfile({required this.role});
  final TenantRole role;
  @override
  Widget build(BuildContext context) {
    final scope = WorkforceScope.of(context);
    void open(String title, String resource, {String? destination}) =>
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CompanyViewScreen(
              role: role,
              title: title,
              resource: resource,
              destination: destination,
            ),
          ),
        );
    return SafeArea(
      child: PageBody(
        padding: TeamLayout.page,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              role == TenantRole.manager ? 'Mais' : 'Perfil',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            const TeamProfileCard(),
            const SizedBox(height: 12),
            const WorkforceActions(showCurrentSelection: false),
            const SizedBox(height: 24),
            if (role == TenantRole.manager) ...[
              if (scope.team.companies.any(
                (company) =>
                    company.user.availableRoles.contains(TenantRole.manager) &&
                    company.user.canManage('CUSTOMERS'),
              )) ...[
                const SectionTitle('Clientes'),
                MoreMenuTile(
                  icon: Icons.qr_code_2_rounded,
                  title: 'Link de convite',
                  onTap: () => open('Link de convite', 'tutorLink'),
                ),
                const SizedBox(height: 12),
              ],
              const SectionTitle('Equipe'),
              if (scope.team.companies.any(
                (company) => company.user.isPrincipal,
              ))
                MoreMenuTile(
                  icon: Icons.manage_accounts_outlined,
                  title: 'Usuários',
                  onTap: () => open('Usuários', 'members'),
                ),
              MoreMenuTile(
                icon: Icons.badge_outlined,
                title: 'Profissionais',
                onTap: () => open('Profissionais', 'professionals'),
              ),
              MoreMenuTile(
                icon: Icons.event_available_outlined,
                title: 'Disponibilidade',
                onTap: () => open(
                  'Disponibilidade',
                  'professionals',
                  destination: 'availability',
                ),
              ),
              const SizedBox(height: 12),
              const SectionTitle('Funcionamento'),
              MoreMenuTile(
                icon: Icons.storefront_outlined,
                title: 'Horário de funcionamento',
                onTap: () => open('Horário de funcionamento', 'scheduling'),
              ),
            ],
            if ([TenantRole.manager, TenantRole.attendant].contains(role))
              MoreMenuTile(
                icon: Icons.event_busy_outlined,
                title: 'Bloqueios de agenda',
                onTap: () => open('Bloqueios de agenda', 'blocks'),
              ),
            if ([TenantRole.manager, TenantRole.attendant].contains(role)) ...[
              MoreMenuTile(
                icon: Icons.local_shipping_outlined,
                title: 'Transportes',
                onTap: () => open('Transportes', 'transports'),
              ),
              MoreMenuTile(
                icon: Icons.inbox_outlined,
                title: 'Pedidos de transporte',
                onTap: () => open('Pedidos de transporte', 'transportRequests'),
              ),
              MoreMenuTile(
                icon: Icons.settings_outlined,
                title: 'Configuração de transporte',
                onTap: () =>
                    open('Configuração de transporte', 'transportPolicy'),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Para cadastrar ou configurar, selecione uma empresa no filtro ou abra a empresa na lista da área desejada.',
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              style: AppButtonStyles.dangerOutlined,
              onPressed: scope.busy ? null : () => confirmSignOut(context),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sair'),
            ),
          ],
        ),
      ),
    );
  }
}
