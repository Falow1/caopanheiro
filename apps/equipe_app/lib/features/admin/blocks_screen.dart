import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppRadii;

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../state/app_scope.dart';
import 'block_form_screen.dart';

class BlocksScreen extends StatelessWidget {
  const BlocksScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final user = controller.user;
    final allowed =
        user != null &&
        ((user.isManager && user.canManage('APPOINTMENTS')) ||
            user.canManageBlocks);
    if (!allowed) {
      return const Scaffold(
        body: Center(child: Text('Acesso restrito à equipe da empresa.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Bloqueios de agenda')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
        itemCount: controller.blocks.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, index) {
          final item = controller.blocks[index];
          return Card(
            child: ListTile(
              onTap:
                  controller.catalogOffline ||
                      (!user.isManager && !item.canEditNow)
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BlockFormScreen(block: item),
                      ),
                    ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 17,
                vertical: 10,
              ),
              leading: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: AppRadii.r14,
                ),
                child: Center(
                  child: Text(
                    item.date.day.toString(),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              title: Text(
                item.fullDay ? 'Dia inteiro' : '${item.start} — ${item.end}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: Text(
                '${date(item.date)} · ${item.reason}${!user.isManager && !item.canEditNow ? '\nSomente o gestor pode alterar este bloqueio.' : ''}',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: controller.catalogOffline
            ? null
            : () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BlockFormScreen()),
              ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Novo bloqueio'),
      ),
    );
  }
}
