import 'confirm_sign_out.dart';
import 'delete_own_account_button.dart';
import 'own_profile_form_screen.dart';
import 'package:caopanheiro_core/caopanheiro_core.dart' show displayPhone;
import '../auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppContentCard, AppButtonStyles, AppGoogleButton, AppTextStyles;
import '../../core/app_theme.dart';
import '../../core/widgets.dart';
import '../../state/app_scope.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context), user = controller.user;
    if (user == null) return const SizedBox.shrink();
    final companies = controller.profileCompanies;
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              child: CircleAvatar(
                radius: 42,
                backgroundColor: AppColors.mint,
                child: Text(
                  user.name.trim().isEmpty
                      ? '?'
                      : user.name.trim().substring(0, 1),
                  style: Theme.of(
                    context,
                  ).textTheme.displaySmall?.copyWith(color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              user.name,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            Text(
              user.isPrincipal ? 'Gestor principal' : user.roleLabel,
              textAlign: TextAlign.center,
            ),
            if (user.isManager && companies.length == 1) ...[
              const SizedBox(height: 4),
              Text(companies.single.name, textAlign: TextAlign.center),
              Text(
                companies.single.statusLabel,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 28),
            AppContentCard(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  const Icon(Icons.badge_outlined),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Perfil de acesso',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.isPrincipal
                              ? 'Gestor principal'
                              : user.roleLabel,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (user.phone.isNotEmpty || controller.ownProfileEditable) ...[
              const SizedBox(height: 24),
              const SectionTitle('Seus dados'),
              const SizedBox(height: 12),
              AppContentCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.phone_outlined),
                      title: const Text('Telefone'),
                      subtitle: Text(
                        user.phone.isEmpty
                            ? 'Não informado'
                            : displayPhone(user.phone),
                      ),
                    ),
                    if (controller.ownProfileEditable) ...[
                      const SizedBox(height: 8),
                      const EditOwnProfileButton(),
                    ],
                  ],
                ),
              ),
            ],
            if (user.isManager && companies.length > 1) ...[
              const SizedBox(height: 24),
              const SectionTitle('Empresas vinculadas'),
              const SizedBox(height: 12),
              AppContentCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var index = 0; index < companies.length; index++) ...[
                      if (index > 0) const SizedBox(height: 12),
                      Text(companies[index].name),
                      const SizedBox(height: 4),
                      Text(
                        companies[index].statusLabel,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (controller.googleAvailable) ...[
              const SizedBox(height: 24),
              if (controller.signInProviders.contains('google.com'))
                const ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 4),
                  leading: Icon(Icons.verified_user_outlined),
                  title: Text('Conta Google vinculada'),
                  subtitle: Text(
                    'Você pode entrar com o Google neste aplicativo.',
                  ),
                )
              else ...[
                AppGoogleButton(
                  label: 'Vincular conta Google',
                  onPressed: controller.busy || controller.readOnly
                      ? null
                      : () async {
                          final linked = await controller.linkGoogle();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                linked
                                    ? 'Conta Google vinculada.'
                                    : controller.error ??
                                          'Não foi possível vincular o Google.',
                              ),
                            ),
                          );
                        },
                ),
                const SizedBox(height: 6),
                const Text(
                  'O Google substitui apenas a senha. Seus vínculos e funções nos petshops não mudam.',
                  style: AppTextStyles.captionMuted,
                ),
              ],
            ],
            const SizedBox(height: 24),
            if (!user.isManager)
              TextButton.icon(
                style: AppButtonStyles.dangerText,
                onPressed: controller.busy
                    ? null
                    : () => confirmSignOut(context),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sair'),
              ),
            if (!controller.isPrincipalAccount)
              DeleteOwnAccountButton(
                enabled: !controller.busy && !controller.readOnly,
                onDelete: controller.deleteOwnAccount,
                error: () => controller.error,
                onDeleted: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
