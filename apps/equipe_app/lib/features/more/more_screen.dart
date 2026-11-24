import 'team_function_profile_screen.dart';
import 'team_profile_card.dart';
import 'workforce_actions.dart';
import 'tips_replay_tile.dart';
import 'more_menu_tile.dart';
import '../admin/workforce_members_screen.dart';
import '../agenda/transport_screen.dart';
import '../customers/tutor_join_link_screen.dart';

import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppScreenTips, AppTourTarget;
import '../../core/screen_tips.dart';

import '../../core/app_theme.dart';
import '../../core/widgets.dart';
import '../../state/app_scope.dart';
import '../admin/availability_screen.dart';
import '../admin/blocks_screen.dart';
import '../admin/business_hours_screen.dart';
import '../admin/professionals_screen.dart';
import 'confirm_sign_out.dart';
import '../auth/company_selection_screen.dart';
import 'plan_lock.dart';
import 'plan_screen.dart';
import 'profile_screen.dart';
import 'support_screen.dart';
import 'renewal_screen.dart' show showOnlinePaymentsSoon;

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final user = controller.user;
    // The outgoing route can rebuild after signOut clears the session.
    if (user == null) return const SizedBox.shrink();
    if (!user.isManager && controller.unified) {
      return TeamFunctionProfileScreen(
        tipScreen: TipScreens.profile,
        email: '',
        phone: '',
        operations: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionTitle('Operação'),
            _transportTile(context),
            if (user.canManageBlocks)
              MoreMenuTile(
                icon: Icons.event_busy_outlined,
                title: 'Bloqueios de agenda',
                onTap: () => _open(context, const BlocksScreen()),
              ),
          ],
        ),
      );
    }
    return AppScreenTips(
      screen: TipScreens.more,
      tips: TeamTips.more,
      child: Scaffold(
        body: SafeArea(
          child: PageBody(
            padding: TeamLayout.page,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  user.isManager ? 'Mais' : 'Perfil',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                const TeamProfileCard(),
                if (user.isManager &&
                    controller.catalogOnly &&
                    controller.companies.length > 1 &&
                    !controller.unified) ...[
                  const SizedBox(height: 5),
                  if (!controller.unified && controller.companies.length > 1)
                    TextButton(
                      onPressed: controller.busy
                          ? null
                          : () {
                              controller.clearCompany();
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const CompanySelectionScreen(),
                                ),
                                (_) => false,
                              );
                            },
                      child: const Text('Trocar petshop vinculado'),
                    ),
                ],
                if (controller.unified && user.isManager)
                  const SizedBox(height: 12),
                if (controller.unified)
                  AppTourTarget(
                    id: TipTargets.workforce,
                    child: WorkforceActions(
                      showCurrentSelection: !user.isManager,
                    ),
                  ),
                const SizedBox(height: 24),
                if (user.isManager) ...[
                  ..._section('Clientes', [
                    if (controller.tutorJoinLinkAvailable)
                      AppTourTarget(
                        id: TipTargets.moreInviteLink,
                        child: controller.entitlements.tutorApp
                            ? MoreMenuTile(
                                icon: Icons.qr_code_2_rounded,
                                title: 'Link de convite',
                                count: controller.pendingTutorReturns,
                                onTap: () =>
                                    _open(context, const TutorJoinLinkScreen()),
                              )
                            : MoreMenuTile(
                                icon: Icons.qr_code_2_rounded,
                                title: 'Link de convite',
                                lockedLabel: 'Planos pagos',
                                onTap: () => showPlanLocked(
                                  context,
                                  title: tutorAppLockedTitle,
                                  message: tutorAppLockedMessage,
                                ),
                              ),
                      ),
                  ]),
                  ..._section('Equipe', [
                    if (controller.unified && user.canManagePeople)
                      MoreMenuTile(
                        icon: Icons.manage_accounts_outlined,
                        title: 'Usuários',
                        onTap: () => _open(
                          context,
                          const WorkforceMembersScreen(management: true),
                        ),
                      ),
                    AppTourTarget(
                      id: TipTargets.moreTeam,
                      child: MoreMenuTile(
                        icon: Icons.badge_outlined,
                        title: 'Profissionais',
                        onTap: () =>
                            _open(context, const ProfessionalsScreen()),
                      ),
                    ),
                    if (user.canManage('PROFESSIONALS'))
                      MoreMenuTile(
                        icon: Icons.event_available_outlined,
                        title: 'Disponibilidade',
                        onTap: () => _open(context, const AvailabilityScreen()),
                      ),
                  ]),
                  ..._section('Funcionamento', [
                    if (user.canManage('SETTINGS'))
                      MoreMenuTile(
                        icon: Icons.storefront_outlined,
                        title: 'Horário de funcionamento',
                        onTap: () =>
                            _open(context, const BusinessHoursScreen()),
                      ),
                    if (user.canManageBlocks)
                      MoreMenuTile(
                        icon: Icons.event_busy_outlined,
                        title: 'Bloqueios de agenda',
                        onTap: () => _open(context, const BlocksScreen()),
                      ),
                    if (user.canManage('TRANSPORT') ||
                        user.canManage('SETTINGS'))
                      _transportTile(context),
                    // Payment of the tutor to the petshop in the app (P3),
                    // announced until the payment provider exists (E2).
                    if (user.canManage('SETTINGS'))
                      AppTourTarget(
                        id: TipTargets.morePayments,
                        child: MoreMenuTile(
                          icon: Icons.payments_outlined,
                          title: 'Receber pelo app',
                          soonLabel: 'Em breve',
                          onTap: () => showOnlinePaymentsSoon(context),
                        ),
                      ),
                  ]),
                  ..._section('Plano', [
                    if (controller.companyExtrasAvailable)
                      MoreMenuTile(
                        icon: Icons.workspace_premium_outlined,
                        title: 'Plano e assinatura',
                        onTap: () => _open(context, const PlanScreen()),
                      ),
                  ]),
                  ..._section('Ajuda', [
                    if (controller.companyExtrasAvailable)
                      MoreMenuTile(
                        icon: Icons.support_agent_rounded,
                        title: 'Suporte da plataforma',
                        onTap: () => _open(context, const SupportScreen()),
                      ),
                    if (controller.tipsAvailable) const TipsReplayTile(),
                  ]),
                  ..._section('Conta', [
                    MoreMenuTile(
                      icon: Icons.logout_rounded,
                      title: 'Sair',
                      color: AppColors.danger,
                      onTap: () => confirmSignOut(context),
                    ),
                  ]),
                ],
                if (!user.isManager) ...[
                  const SectionTitle('Operação'),
                  if (user.canManage('TRANSPORT') || user.canManage('SETTINGS'))
                    MoreMenuTile(
                      icon: Icons.local_shipping_outlined,
                      title: 'Transporte',
                      onTap: () => _open(context, const TransportScreen()),
                    ),
                  if (user.canManageBlocks) ...[
                    MoreMenuTile(
                      icon: Icons.event_busy_outlined,
                      title: 'Bloqueios de agenda',
                      onTap: () => _open(context, const BlocksScreen()),
                    ),
                    const SizedBox(height: 20),
                  ],
                ],
                if (!user.isManager) ...[
                  const SectionTitle('Conta'),
                  MoreMenuTile(
                    icon: Icons.person_outline_rounded,
                    title: 'Perfil',
                    onTap: () => _open(context, const ProfileScreen()),
                  ),
                  MoreMenuTile(
                    icon: Icons.logout_rounded,
                    title: 'Sair',
                    color: AppColors.danger,
                    onTap: () => confirmSignOut(context),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A category shows its title only when at least one item is visible.
  List<Widget> _section(String title, List<Widget> items) => items.isEmpty
      ? const []
      : [SectionTitle(title), ...items, const SizedBox(height: 12)];

  /// Transport is in the Completo plan (A1); on other plans the tile says so
  /// and still opens the transports already registered.
  Widget _transportTile(BuildContext context) {
    final controller = AppScope.of(context);
    if (controller.entitlements.transport) {
      return MoreMenuTile(
        icon: Icons.local_shipping_outlined,
        title: 'Transporte',
        onTap: () => _open(context, const TransportScreen()),
      );
    }
    return MoreMenuTile(
      icon: Icons.local_shipping_outlined,
      title: 'Transporte',
      lockedLabel: 'Completo',
      onTap: () => showPlanLocked(
        context,
        title: transportLockedTitle,
        message: transportLockedMessage,
        openAnyway: () => _open(context, const TransportScreen()),
      ),
    );
  }

  void _open(BuildContext context, Widget page) {
    if (AppScope.of(context).busy) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }
}
