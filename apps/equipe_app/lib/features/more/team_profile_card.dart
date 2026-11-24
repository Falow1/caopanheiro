import '../../state/workforce_scope.dart';
import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppRadii, AppStatusBadge;
import '../../core/app_theme.dart';
import '../../state/app_scope.dart';
import 'profile_screen.dart';

class TeamProfileCard extends StatelessWidget {
  const TeamProfileCard({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context), user = controller.user;
    if (user == null) return const SizedBox.shrink();
    final all = WorkforceScope.maybeOf(context)?.allCompanies == true;
    final principals = controller.companies
        .where((company) => company.user.isPrincipal)
        .length;
    final principalLabel = principals == 1
        ? 'Gestor principal em 1 empresa'
        : 'Gestor principal em $principals empresas';
    final allLabel = principals == 0
        ? user.roleLabel
        : user.isManager
        ? principalLabel
        : '$principalLabel · ${user.roleLabel}';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        button: true,
        label: 'Abrir meu perfil',
        child: InkWell(
          key: ValueKey(
            user.isManager ? 'manager-profile-card' : 'team-profile-card',
          ),
          borderRadius: AppRadii.card,
          onTap: controller.busy
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.mint,
                      child: Text(
                        user.name.trim().isEmpty
                            ? '?'
                            : user.name.trim().substring(0, 1),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          if (!all &&
                              ((user.isManager &&
                                      controller.profileCompanies.length ==
                                          1) ||
                                  (!user.isManager &&
                                      controller.company != null))) ...[
                            const SizedBox(height: 4),
                            Text(
                              user.isManager
                                  ? controller.profileCompanies.single.name
                                  : controller.company!.name,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                          const SizedBox(height: 8),
                          AppStatusBadge(
                            label: all
                                ? allLabel
                                : user.isPrincipal
                                ? (user.isManager
                                      ? 'Gestor principal'
                                      : 'Gestor principal · ${user.roleLabel}')
                                : user.isManager
                                ? 'Gestão'
                                : user.roleLabel,
                            background: AppColors.mint,
                            foreground: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (controller.profileCompanies.length > 1) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.storefront_outlined, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          controller.profileCompanies.length == 1
                              ? '1 empresa vinculada'
                              : '${controller.profileCompanies.length} empresas vinculadas',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
