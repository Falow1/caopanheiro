import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppButtonStyles, AppGoogleButton, AppTextStyles;

import '../../core/app_theme.dart';
import '../../core/widgets.dart';
import '../../state/app_scope.dart';
import 'confirm_sign_out.dart';
import 'password_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    if (controller.admin == null) return const SizedBox.shrink();
    final admin = controller.admin;
    // The outgoing route can rebuild after signOut clears the session.
    if (admin == null) return const SizedBox.shrink();
    return Scaffold(
      appBar: AppBar(title: const Text('Meu perfil')),
      body: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              child: CircleAvatar(
                radius: 42,
                backgroundColor: AppColors.mint,
                child: Text(
                  admin.name.substring(0, 1),
                  style: Theme.of(
                    context,
                  ).textTheme.displaySmall?.copyWith(color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 15),
            Text(
              admin.name,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            Text(
              admin.role,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.violet,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.mail_outline_rounded),
                      title: const Text('E-mail'),
                      subtitle: Text(admin.email),
                    ),
                    ListTile(
                      leading: const Icon(Icons.admin_panel_settings_outlined),
                      title: const Text('Função'),
                      subtitle: Text(admin.role),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => _changePassword(context),
              icon: const Icon(Icons.password_rounded),
              label: const Text('Alterar senha'),
            ),
            if (controller.googleAvailable) ...[
              const SizedBox(height: 10),
              if (controller.providers.contains('google.com'))
                const ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 4),
                  leading: Icon(Icons.verified_user_outlined),
                  title: Text('Conta Google vinculada'),
                  subtitle: Text(
                    'Você pode entrar com o Google. O código por e-mail continua sendo pedido.',
                  ),
                )
              else ...[
                AppGoogleButton(
                  label: 'Vincular conta Google',
                  onPressed: controller.busy
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
                  'O Google substitui apenas a senha. O acesso administrativo e o código por e-mail não mudam.',
                  style: AppTextStyles.captionMuted,
                ),
              ],
            ],
            const SizedBox(height: 8),
            TextButton.icon(
              style: AppButtonStyles.dangerText,
              onPressed: () => confirmSignOut(context),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sair'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changePassword(BuildContext context) => Navigator.of(
    context,
  ).push<void>(MaterialPageRoute(builder: (_) => const PasswordScreen()));
}
