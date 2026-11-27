import 'delete_own_account_button.dart';
import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppScreenTips, AppTourTarget;
import '../../core/screen_tips.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppGoogleButton, AppRadii, AppTextStyles;

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/confirm_dialogs.dart';
import '../../domain/policies/contact_input.dart' show displayPhone;
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
    final two = tutorTwoColumns(context);
    // The person: name, phone and e-mail, with Editar dados at the end.
    final person = _Group(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.mint,
                child: Text(
                  tutor.name.substring(0, 1).toUpperCase(),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  tutor.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
        ),
        const _Line(),
        _InfoTile(
          icon: Icons.phone_outlined,
          label: 'Telefone',
          value: displayPhone(tutor.phone),
        ),
        _InfoTile(
          icon: Icons.mail_outline_rounded,
          label: 'E-mail',
          value: tutor.email,
        ),
        // The address of the account for the transport, when it is kept.
        if (controller.addressAvailable)
          _InfoTile(
            icon: Icons.home_outlined,
            label: 'Endereço para o transporte',
            value: controller.savedAddress?.label ?? 'Nenhum endereço guardado',
          ),
        // On two columns the card grows to the height of the other column
        // and the button stays at its foot.
        if (two) const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: AppTourTarget(
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
        ),
      ],
    );
    final signOut = OutlinedButton.icon(
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
    );
    // The account: history, Google, help and, at the foot, Sair. Apart,
    // under both cards, the only red one, which deletes the account.
    final account = _Group(
      children: [
        AppTourTarget(
          id: TipTargets.profileHistory,
          child: _ActionRow(
            icon: Icons.history_rounded,
            label: 'Histórico de atendimentos',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            ),
          ),
        ),
        if (controller.integrated) ...[
          const _Line(),
          _GoogleAccess(providers: controller.providers),
        ],
        if (controller.tipsAvailable) ...[
          const _Line(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Text(
              'Ajuda',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
              ),
            ),
          ),
          const _TipsReplay(),
        ],
        if (two) const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: signOut,
        ),
      ],
    );
    final delete = controller.principalManager
        ? null
        : Center(
            child: DeleteOwnAccountButton(
              enabled: !controller.busy,
              onDelete: controller.deleteOwnAccount,
              error: () => controller.error,
              onDeleted: () =>
                  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false,
                  ),
            ),
          );
    if (tutorWide(context)) {
      // Two columns of the same width and height: the person on the left;
      // the account, the help and Sair on the right, ending on one line.
      final left = [
        const SectionHeader(title: 'Seus dados'),
        two ? Expanded(child: person) : person,
      ];
      final right = [
        const SectionHeader(title: 'Conta'),
        two ? Expanded(child: account) : account,
      ];
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
                if (two)
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: FocusTraversalGroup(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: left,
                            ),
                          ),
                        ),
                        const SizedBox(width: 32),
                        Expanded(
                          child: FocusTraversalGroup(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: right,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  ...left,
                  const SizedBox(height: 26),
                  ...right,
                ],
                if (delete != null) ...[const SizedBox(height: 28), delete],
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
              const SectionHeader(title: 'Seus dados'),
              person,
              const SizedBox(height: 22),
              const SectionHeader(title: 'Conta'),
              account,
              if (delete != null) ...[const SizedBox(height: 28), delete],
            ],
          ),
        ),
      ),
    );
  }
}

/// The thin line between the lines of a card.
class _Line extends StatelessWidget {
  const _Line();

  @override
  Widget build(BuildContext context) => const Divider(
    height: 1,
    thickness: 1,
    indent: 16,
    endIndent: 16,
    color: AppColors.line,
  );
}

/// A section of the Profile: one white card with its lines.
class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

/// A line of a section that opens something: icon, text and an arrow.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.opens = true,
  });
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  /// Opens another screen: shows the arrow at the end.
  final bool opens;

  @override
  Widget build(BuildContext context) => TextButton(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.ink,
      minimumSize: const Size.fromHeight(64),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      alignment: Alignment.centerLeft,
      shape: const RoundedRectangleBorder(),
    ),
    onPressed: onPressed,
    child: Row(
      children: [
        _IconBox(icon: icon),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (opens)
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
      ],
    ),
  );
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: const BoxDecoration(
      color: AppColors.mint,
      borderRadius: AppRadii.r12,
    ),
    child: Icon(icon, color: AppColors.primary, size: 22),
  );
}

class _GoogleAccess extends StatelessWidget {
  const _GoogleAccess({required this.providers});
  final List<String> providers;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    if (providers.contains('google.com')) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _IconBox(icon: Icons.verified_user_outlined),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Conta Google vinculada',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Você pode entrar com o Google neste aplicativo.',
                    style: AppTextStyles.captionMuted,
                  ),
                  if (!providers.contains('password')) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'Sua conta não tem senha. Para excluir a conta, crie uma senha em "Esqueci minha senha" na tela de entrada.',
                      style: AppTextStyles.captionMuted,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: AppGoogleButton(
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
    );
  }
}

/// A saved value of the person: icon, name of the value and the value.
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: Row(
      children: [
        _IconBox(icon: icon),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.captionMuted),
              const SizedBox(height: 2),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      ],
    ),
  );
}

/// "Rever dicas": erases the account marks, so every screen shows its tips
/// again, starting with this one.
class _TipsReplay extends StatelessWidget {
  const _TipsReplay();

  @override
  Widget build(BuildContext context) => AppTourTarget(
    id: TipTargets.help,
    child: _ActionRow(
      icon: Icons.lightbulb_outline_rounded,
      label: 'Rever dicas',
      opens: false,
      onPressed: () {
        AppScope.of(context).resetTips();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pronto. As dicas aparecem de novo em cada tela.'),
          ),
        );
      },
    ),
  );
}
