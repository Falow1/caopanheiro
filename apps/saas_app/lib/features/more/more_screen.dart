import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppRadii;

import '../../core/app_theme.dart';
import '../../core/widgets.dart';
import '../../state/app_scope.dart';
import '../plans/plans_screen.dart';
import '../support/breed_suggestions_screen.dart';
import '../support/support_screen.dart';
import 'confirm_sign_out.dart';
import 'health_screen.dart';
import 'profile_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    if (controller.admin == null) return const SizedBox.shrink();
    final admin = controller.admin;
    // The outgoing route can rebuild after signOut clears the session.
    if (admin == null) return const SizedBox.shrink();
    return Scaffold(
      body: SafeArea(
        child: PageBody(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SaasPageTitle('Mais', subtitle: '${admin.name} · ${admin.role}'),
              const SizedBox(height: 24),
              _Menu(
                icon: Icons.sell_outlined,
                title: 'Planos',
                onTap: () => _open(context, const PlansScreen()),
              ),
              _Menu(
                icon: Icons.support_agent_rounded,
                title: 'Suporte e diagnóstico',
                count: AppScope.of(context).supportWaitingCount,
                onTap: () => _open(context, const SupportScreen()),
              ),
              if (controller.breedSuggestionsAvailable)
                _Menu(
                  icon: Icons.pets_outlined,
                  title: 'Raças sugeridas',
                  onTap: () => _open(context, const BreedSuggestionsScreen()),
                ),
              _Menu(
                icon: Icons.monitor_heart_outlined,
                title: 'Saúde da plataforma',
                onTap: () => _open(context, const HealthScreen()),
              ),
              _Menu(
                icon: Icons.person_outline_rounded,
                title: 'Meu perfil',
                onTap: () => _open(context, const ProfileScreen()),
              ),
              _Menu(
                icon: Icons.logout_rounded,
                title: 'Sair',
                color: AppColors.danger,
                onTap: () => confirmSignOut(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
}

class _Menu extends StatelessWidget {
  const _Menu({
    required this.icon,
    required this.title,
    required this.onTap,
    this.color,
    this.count = 0,
  });
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;

  /// Support requests waiting for an answer (A1-s).
  final int count;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color == null
                ? AppColors.mint
                : AppColors.dangerActionSurface,
            borderRadius: AppRadii.r13,
          ),
          child: Icon(icon, color: color ?? AppColors.primary),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: color ?? AppColors.ink,
          ),
        ),
        trailing: count == 0
            ? const Icon(Icons.chevron_right_rounded)
            : Badge(
                label: Text(count > 99 ? '99+' : '$count'),
                child: const Icon(Icons.chevron_right_rounded),
              ),
      ),
    ),
  );
}
