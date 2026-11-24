import '../../core/team_layout.dart';

import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppScreenTips, AppTourTarget;
import '../../core/screen_tips.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppRadii;

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../state/app_scope.dart';
import 'service_form_screen.dart';

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});
  @override
  Widget build(BuildContext context) => AppScreenTips(
    screen: TipScreens.services,
    tips: TeamTips.services,
    ready: !AppScope.of(context).busy,
    child: _content(context),
  );

  Widget _content(BuildContext context) {
    final controller = AppScope.of(context);
    final user = controller.user;
    // The outgoing route can rebuild after signOut clears the session.
    if (user == null) return const SizedBox.shrink();
    final canEdit =
        user.isManager &&
        user.canManage('SERVICES') &&
        !controller.catalogOffline;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: TeamLayout.header,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Serviços',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        Text(
                          controller.catalogOnly
                              ? (controller.company?.name ??
                                    'Catálogo da empresa')
                              : 'Catálogo oferecido no agendamento',
                        ),
                      ],
                    ),
                  ),
                  if (canEdit)
                    IconButton.filled(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ServiceFormScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded),
                    ),
                ],
              ),
            ),
            if (controller.localWarning != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(controller.localWarning!),
              ),
            if (controller.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  controller.error!,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
            if (controller.catalogOnly &&
                controller.services.isEmpty &&
                !controller.busy)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Nenhum serviço disponível nesta consulta.'),
              ),
            Expanded(
              child: ListView.separated(
                padding: TeamLayout.list,
                itemCount: controller.services.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, index) {
                  final service = controller.services[index];
                  return AppTourTarget(
                    id: TipTargets.servicesCard,
                    child: Card(
                      child: ListTile(
                        onTap: canEdit
                            ? () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ServiceFormScreen(service: service),
                                ),
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 17,
                          vertical: 9,
                        ),
                        title: Text(
                          service.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        subtitle: Text(
                          '${service.duration} min · ${money(service.price)}',
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: service.active
                                ? AppColors.mint
                                : AppColors.inactiveSurface,
                            borderRadius: AppRadii.r99,
                          ),
                          child: Text(
                            service.active ? 'Ativo' : 'Inativo',
                            style: TextStyle(
                              color: service.active
                                  ? AppColors.primary
                                  : AppColors.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: canEdit
          ? AppTourTarget(
              id: TipTargets.servicesNew,
              child: FloatingActionButton.extended(
                heroTag: 'team-new-service',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ServiceFormScreen()),
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Novo serviço'),
              ),
            )
          : null,
    );
  }
}
