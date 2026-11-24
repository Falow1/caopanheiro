import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppBrand, AppDimensions, AppRadii, AppTextStyles, AppTourTarget;
import 'package:flutter/material.dart';

import '../../core/screen_tips.dart';
import '../../core/theme/app_theme.dart';
import '../../state/app_scope.dart';
import 'tutor_shell_scope.dart';

/// The four areas of the Tutor, in the order of the tabs.
const tutorDestinations = [
  (Icons.home_outlined, Icons.home_rounded, 'Início'),
  (Icons.calendar_month_outlined, Icons.calendar_month_rounded, 'Agendar'),
  (Icons.pets_outlined, Icons.pets_rounded, 'Pets'),
  (Icons.person_outline_rounded, Icons.person_rounded, 'Perfil'),
];

/// Menu of the Tutor on wide windows, in place of the bottom bar: brand,
/// Novo agendamento, the four areas and, online, the current petshop. It stays
/// beside every inner screen; it scrolls when the window is short. The "Menu"
/// tip highlights the four areas: a target as tall as the window would leave
/// no room for the balloon.
class TutorSideBar extends StatelessWidget {
  const TutorSideBar({super.key, required this.shell});
  final TutorShell shell;

  @override
  Widget build(BuildContext context) => FocusTraversalGroup(
    child: Container(
      width: AppDimensions.tutorSideBarWidth,
      decoration: const BoxDecoration(
        color: AppColors.paper,
        border: Border(right: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        right: false,
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Large text: the mark shrinks instead of overflowing.
                    const FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: AppBrand.tutor(),
                    ),
                    const SizedBox(height: 28),
                    // The only Novo agendamento of the Início on wide
                    // windows: it carries the tip.
                    AppTourTarget(
                      id: TipTargets.homeNew,
                      child: ValueListenableBuilder<bool>(
                        valueListenable: shell.bookingOpen,
                        builder: (context, open, _) => FilledButton.icon(
                          onPressed: open ? null : shell.openBooking,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Novo agendamento'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    AppTourTarget(
                      id: TipTargets.nav,
                      child: ValueListenableBuilder<int>(
                        valueListenable: shell.tab,
                        builder: (context, selected, _) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final (i, item) in tutorDestinations.indexed)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: _Destination(
                                  icon: i == selected ? item.$2 : item.$1,
                                  label: item.$3,
                                  selected: i == selected,
                                  onTap: () => shell.selectTab(i),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(height: 18),
                    _Company(shell: shell),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Destination extends StatelessWidget {
  const _Destination({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: selected ? AppColors.mint : Colors.transparent,
      borderRadius: AppRadii.r16,
      child: InkWell(
        borderRadius: AppRadii.r16,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: selected ? AppColors.primary : AppColors.muted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      color: selected ? AppColors.primary : AppColors.ink,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Current petshop of the online Tutor, its switch and the link to another.
class _Company extends StatelessWidget {
  const _Company({required this.shell});
  final TutorShell shell;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    if (!controller.integrated) return const SizedBox.shrink();
    final name =
        controller.companies
            .where((company) => company.id == controller.companyId)
            .firstOrNull
            ?.name ??
        'Empresa';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Empresa', style: AppTextStyles.captionMuted),
                    const SizedBox(height: 2),
                    Text(name, style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
              ),
              if (controller.companies.length > 1)
                PopupMenuButton<String>(
                  tooltip: 'Trocar empresa',
                  icon: const Icon(Icons.unfold_more_rounded),
                  enabled: !controller.busy,
                  onSelected: (id) {
                    controller.selectCompany(id);
                  },
                  itemBuilder: (_) => [
                    for (final company in controller.companies)
                      PopupMenuItem(
                        value: company.id,
                        child: Text(company.name),
                      ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              textStyle: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontSize: 14),
            ),
            onPressed: controller.busy ? null : shell.linkCompany,
            icon: const Icon(Icons.add_business_outlined, size: 20),
            label: const Text('Vincular outro petshop'),
          ),
        ),
      ],
    );
  }
}
