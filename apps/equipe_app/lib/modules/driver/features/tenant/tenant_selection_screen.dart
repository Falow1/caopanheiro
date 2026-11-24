import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppRadii;

import '../../core/app_theme.dart';
import '../../core/widgets.dart';
import '../../state/app_scope.dart';
import '../navigation/main_shell.dart';

class TenantSelectionScreen extends StatelessWidget {
  const TenantSelectionScreen({super.key, this.allowBack = false});
  final bool allowBack;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return Scaffold(
      appBar: allowBack ? AppBar(title: const Text('Trocar empresa')) : null,
      body: SafeArea(
        child: PageBody(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!allowBack) const Brand(),
              if (!allowBack) const SizedBox(height: 42),
              Text(
                'Selecione a empresa',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Você verá somente os transportes vinculados à empresa ativa.',
              ),
              const SizedBox(height: 24),
              ...controller.memberships.map((membership) {
                final count = controller.todayCount(membership.tenantId);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: ListTile(
                      onTap: () {
                        controller.selectTenant(membership.tenantId);
                        if (allowBack) {
                          Navigator.pop(context);
                        } else {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MainShell(),
                            ),
                          );
                        }
                      },
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      leading: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppColors.mint,
                          borderRadius: AppRadii.r13,
                        ),
                        child: const Icon(
                          Icons.storefront_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                      title: Text(
                        membership.tenantName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      subtitle: Text(
                        '$count ${count == 1 ? 'transporte' : 'transportes'} hoje',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
