import 'package:caopanheiro_core/caopanheiro_core.dart' show displayPhone;
import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppScreenTips, AppTourTarget;
import '../../core/screen_tips.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppButtonStyles, AppContentCard;
import '../../core/widgets.dart';
import '../../state/app_scope.dart';
import 'team_profile_card.dart';
import 'workforce_actions.dart';
import 'confirm_sign_out.dart';
import 'own_profile_form_screen.dart';
import 'tips_replay_tile.dart';

class TeamFunctionProfileScreen extends StatelessWidget {
  const TeamFunctionProfileScreen({
    super.key,
    required this.email,
    required this.phone,
    this.operations,
    this.tipScreen = TipScreens.profile,
  });
  final String email, phone;

  /// Tips of the function shown: attendant, professional or driver.
  final String tipScreen;
  final Widget? operations;
  @override
  Widget build(BuildContext context) => AppScreenTips(
    screen: tipScreen,
    tips: TeamTips.profile,
    child: _content(context),
  );

  Widget _content(BuildContext context) {
    final controller = AppScope.of(context);
    final user = controller.user;
    if (user == null) return const SizedBox.shrink();
    // The phone the person saved; the function's own record is the fallback.
    final shownPhone = user.phone.isNotEmpty ? user.phone : phone;
    final editable = controller.ownProfileEditable;
    return Scaffold(
      body: SafeArea(
        child: PageBody(
          padding: TeamLayout.page,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Perfil', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              const TeamProfileCard(),
              const SizedBox(height: 12),
              AppTourTarget(
                id: TipTargets.workforce,
                child: const WorkforceActions(showCurrentSelection: false),
              ),
              if (operations != null) ...[
                const SizedBox(height: 24),
                AppTourTarget(id: TipTargets.operations, child: operations!),
              ],
              if (email.isNotEmpty || shownPhone.isNotEmpty || editable) ...[
                const SizedBox(height: 24),
                const SectionTitle('Seus dados'),
                AppContentCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (email.isNotEmpty)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.mail_outline_rounded),
                          title: const Text('E-mail'),
                          subtitle: Text(email),
                        ),
                      if (shownPhone.isNotEmpty)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.phone_outlined),
                          title: const Text('Telefone'),
                          subtitle: Text(displayPhone(shownPhone)),
                        ),
                      if (editable) ...[
                        const SizedBox(height: 8),
                        const EditOwnProfileButton(),
                      ],
                    ],
                  ),
                ),
              ],
              if (controller.tipsAvailable) ...[
                const SizedBox(height: 24),
                const SectionTitle('Ajuda'),
                const TipsReplayTile(),
              ],
              const SizedBox(height: 24),
              OutlinedButton.icon(
                style: AppButtonStyles.dangerOutlined,
                onPressed: controller.busy
                    ? null
                    : () => confirmSignOut(context),
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
