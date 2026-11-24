import 'delete_own_account_button.dart';
import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppScreenTips, AppTourTarget;
import '../../core/screen_tips.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppGoogleButton, AppContentCard, AppRadii, AppTextStyles;

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/confirm_dialogs.dart';
import '../../state/app_scope.dart';
import '../appointments/history_screen.dart';
import '../auth/login_screen.dart';
import '../navigation/tutor_wide_layout.dart';
import 'profile_edit_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, this.companyActions});
  final Widget? companyActions;

  @override
  Widget build(BuildContext context) => AppScreenTips(
    screen: TipScreens.profile,
    tips: tutorTips(context, TutorTips.profile),
    child: _content(context),
  );

  Widget _content(BuildContext context) {
    final controller = AppScope.of(context);
    final tutor = controller.tutor;
    // The outgoing route can rebuild after signOut clears the session.
    if (tutor == null) return const SizedBox.shrink();
    final title = Text(
      'Perfil',
      style: Theme.of(context).textTheme.headlineMedium,
    );
    final person = <Widget>[
      AppContentCard(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.mint,
              child: Text(
                tutor.name.substring(0, 1).toUpperCase(),
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(color: AppColors.primary),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The e-mail is in its line, under the card.
                  Text(
                    tutor.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      _InfoTile(
        icon: Icons.phone_outlined,
        label: 'Telefone',
        value: tutor.phone,
      ),
      _InfoTile(
        icon: Icons.mail_outline_rounded,
        label: 'E-mail',
        value: tutor.email,
      ),
      const SizedBox(height: 22),
      AppTourTarget(
        id: TipTargets.profileEdit,
        child: OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
          ),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Editar dados'),
        ),
      ),
    ];
    // In groups: the account, the help, the exit and, apart, the only red
    // one, which deletes the account.
    final account = <Widget>[
      const SectionHeader(title: 'Conta'),
      AppTourTarget(
        id: TipTargets.profileHistory,
        child: OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HistoryScreen()),
          ),
          icon: const Icon(Icons.history_rounded),
          label: const Text('Histórico de atendimentos'),
        ),
      ),
      if (controller.integrated) ...[
        const SizedBox(height: 10),
        _GoogleAccess(providers: controller.providers),
      ],
      if (controller.tipsAvailable) ...[
        const SizedBox(height: 22),
        const SectionHeader(title: 'Ajuda'),
        const _TipsReplay(),
      ],
      const SizedBox(height: 22),
      OutlinedButton.icon(
        onPressed: () async {
          if (!await confirmSignOut(context) || !context.mounted) {
            return;
          }
          controller.signOut(forgetInvite: true);
          // The whole window, not the content area beside the menu.
          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (_) => false,
          );
        },
        icon: const Icon(Icons.logout_rounded),
        label: const Text('Sair'),
      ),
      if (!controller.principalManager) ...[
        const SizedBox(height: 28),
        DeleteOwnAccountButton(
          enabled: !controller.busy,
          onDelete: controller.deleteOwnAccount,
          error: () => controller.error,
          onDeleted: () =>
              Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              ),
        ),
      ],
    ];
    if (tutorWide(context)) {
      // The person on the left; the account and help on the right.
      return Scaffold(
        body: SafeArea(
          child: TutorPageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: title),
                    const TutorRefreshButton(),
                  ],
                ),
                const SizedBox(height: 24),
                // Each column with its header, in the same line.
                TutorTwoColumns(
                  leftFlex: 1,
                  rightFlex: 1,
                  left: [const SectionHeader(title: 'Seus dados'), ...person],
                  right: account,
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: PageBody(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The title first, then the petshop.
              title,
              const SizedBox(height: 26),
              ?companyActions,
              ...person,
              const SizedBox(height: 26),
              ...account,
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleAccess extends StatelessWidget {
  const _GoogleAccess({required this.providers});
  final List<String> providers;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    if (providers.contains('google.com')) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 4),
            leading: Icon(Icons.verified_user_outlined),
            title: Text('Conta Google vinculada'),
            subtitle: Text('Você pode entrar com o Google neste aplicativo.'),
          ),
          if (!providers.contains('password'))
            const Text(
              'Sua conta não tem senha. Para excluir a conta, crie uma senha em "Esqueci minha senha" na tela de entrada.',
              style: AppTextStyles.captionMuted,
            ),
        ],
      );
    }
    return AppGoogleButton(
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
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
    leading: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: AppRadii.r14,
      ),
      child: Icon(icon, color: AppColors.primary),
    ),
    title: Text(label, style: AppTextStyles.captionMuted),
    subtitle: Text(value, style: Theme.of(context).textTheme.titleMedium),
  );
}

/// "Rever dicas": erases the account marks, so every screen shows its tips
/// again, starting with this one.
class _TipsReplay extends StatelessWidget {
  const _TipsReplay();

  @override
  Widget build(BuildContext context) => AppTourTarget(
    id: TipTargets.help,
    child: OutlinedButton.icon(
      onPressed: () {
        AppScope.of(context).resetTips();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pronto. As dicas aparecem de novo em cada tela.'),
          ),
        );
      },
      icon: const Icon(Icons.lightbulb_outline_rounded),
      label: const Text('Rever dicas'),
    ),
  );
}
