import '../../../../../features/more/team_function_profile_screen.dart';
import '../../../../../features/more/profile_screen.dart' as account;
import '../../../../features/more/workforce_actions.dart';
import '../../../../features/more/confirm_sign_out.dart' show askSignOut;
import '../../../../state/workforce_scope.dart';
import 'package:flutter/material.dart';
import '../../../../core/screen_tips.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppButtonStyles;

import '../../core/app_theme.dart';
import '../../core/widgets.dart';
import '../../state/app_scope.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, this.companyActions});
  final Widget? companyActions;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final professional = controller.professional;
    final companyName =
        WorkforceScope.maybeOf(context)?.team.company?.name ??
        controller.companies
            .where((company) => company.id == controller.companyId)
            .firstOrNull
            ?.name;
    // The outgoing route can rebuild after signOut clears the session.
    if (professional == null) return const SizedBox.shrink();
    if (WorkforceScope.maybeOf(context) != null) {
      return TeamFunctionProfileScreen(
        tipScreen: TipScreens.proProfile,
        email: professional.email,
        phone: professional.phone,
      );
    }
    return Scaffold(
      body: SafeArea(
        child: PageBody(
          padding: TeamLayout.page,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ?companyActions,
              Text('Perfil', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 28),
              Align(
                child: CircleAvatar(
                  radius: 43,
                  backgroundColor: AppColors.mint,
                  child: Text(
                    professional.name.substring(0, 1),
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Text(
                professional.name,
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              if (companyName != null && companyName.isNotEmpty)
                Text(
                  companyName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              const SizedBox(height: 28),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.mail_outline_rounded),
                        title: const Text('E-mail'),
                        subtitle: Text(professional.email),
                      ),
                      ListTile(
                        leading: const Icon(Icons.phone_outlined),
                        title: const Text('Telefone'),
                        subtitle: Text(professional.phone),
                      ),
                      ListTile(
                        leading: const Icon(Icons.badge_outlined),
                        title: const Text('Função'),
                        subtitle: Text(professional.role),
                      ),
                    ],
                  ),
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
              OutlinedButton.icon(
                style: AppButtonStyles.dangerOutlined,
                onPressed: () async {
                  if (!await askSignOut(context) || !context.mounted) return;
                  controller.signOut();
                  Navigator.of(context).pushAndRemoveUntil(
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
