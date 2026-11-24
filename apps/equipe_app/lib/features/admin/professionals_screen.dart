import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppTextStyles;

import '../../core/app_theme.dart';
import '../../state/app_scope.dart';
import 'professional_form_screen.dart';
import 'workforce_members_screen.dart';

class ProfessionalsScreen extends StatelessWidget {
  const ProfessionalsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final items = controller.professionals;
    return Scaffold(
      appBar: AppBar(title: const Text('Profissionais')),
      body: Column(
        children: [
          if (controller.error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(controller.error!),
            ),
          if (controller.user?.canManagePeople == true)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: controller.busy
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const WorkforceMembersScreen(),
                          ),
                        ),
                  icon: const Icon(Icons.groups_outlined),
                  label: const Text('Equipe e funções'),
                ),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await controller.refreshProfessionals();
              },
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, index) {
                  final item = items[index];
                  return Card(
                    child: ListTile(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ProfessionalFormScreen(professional: item),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 17,
                        vertical: 9,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.mint,
                        child: Text(
                          item.name.substring(0, 1),
                          style: AppTextStyles.primaryStrong,
                        ),
                      ),
                      title: Text(
                        item.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      subtitle: Text(item.specialty),
                      trailing: Text(
                        item.active ? 'Ativo' : 'Inativo',
                        style: TextStyle(
                          color: item.active
                              ? AppColors.primary
                              : AppColors.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: controller.user?.canManagePeople != true
          ? null
          : FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProfessionalFormScreen(),
                ),
              ),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Convidar profissional'),
            ),
    );
  }
}
