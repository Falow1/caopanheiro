import 'package:caopanheiro_core/caopanheiro_core.dart' show displayPhone;
import '../../../../../features/more/team_function_profile_screen.dart';
import '../../../../../features/more/profile_screen.dart' as account;
import '../../../../features/more/workforce_actions.dart';
import '../../../../features/more/confirm_sign_out.dart' show askSignOut;
import '../../../../state/workforce_scope.dart';
import 'package:flutter/material.dart';
import '../../../../core/screen_tips.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppButtonStyles, AppContentCard, AppTextStyles;

import '../../core/app_theme.dart';
import '../../core/widgets.dart';
import '../../state/app_scope.dart';
import '../auth/login_screen.dart';
import '../tenant/tenant_selection_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final profile = controller.profile;
    final unified = WorkforceScope.maybeOf(context) != null;
    // The outgoing route can rebuild after signOut clears the session.
    final activeTenant = controller.activeTenant;
    if (profile == null || activeTenant == null) {
      return const SizedBox.shrink();
    }
    if (unified) {
      return TeamFunctionProfileScreen(
        tipScreen: TipScreens.driverProfile,
        email: profile.email,
        phone: profile.phone,
      );
    }
    return Scaffold(
      body: SafeArea(
        child: PageBody(
          padding: TeamLayout.page,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Perfil', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 28),
              Align(
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.mint,
                  child: Text(
                    profile.name.substring(0, 1),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                profile.name,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const Text('Entregador', textAlign: TextAlign.center),
              const SizedBox(height: 26),
              AppContentCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    _Info('E-mail', profile.email),
                    _Info(
                      'Telefone',
                      displayPhone(profile.phone),
                      last: unified || controller.memberships.length <= 1,
                    ),
                    if (!unified && controller.memberships.length > 1)
                      _Info(
                        'Petshop ativo',
                        activeTenant.tenantName,
                        last: true,
                      ),
                  ],
                ),
              ),
              const WorkforceActions(),
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const account.ProfileScreen(),
                  ),
                ),
                icon: const Icon(Icons.manage_accounts_outlined),
                label: const Text('Minha conta'),
              ),

              const SizedBox(height: 22),
              if (!unified && controller.memberships.length > 1) ...[
                const SectionTitle('Petshops vinculados'),
                ...controller.memberships.map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.storefront_outlined,
                      color: AppColors.primary,
                    ),
                    title: Text(item.tenantName),
                    trailing: item.tenantId == controller.activeTenantId
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.primary,
                          )
                        : null,
                  ),
                ),
                if (controller.memberships.length > 1) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const TenantSelectionScreen(allowBack: true),
                      ),
                    ),
                    icon: const Icon(Icons.swap_horiz_rounded),
                    label: const Text('Trocar petshop vinculado'),
                  ),
                ],
              ],
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: AppButtonStyles.dangerOutlined,
                onPressed: () async {
                  if (!await askSignOut(context) || !context.mounted) return;
                  controller.signOut();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false,
                  );
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sair'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.label, this.value, {this.last = false});
  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: last ? 0 : 14),
    child: Row(
      children: [
        SizedBox(
          width: 105,
          child: Text(label, style: AppTextStyles.captionMuted),
        ),
        Expanded(child: Text(value, style: AppTextStyles.value)),
      ],
    ),
  );
}
