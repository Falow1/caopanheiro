import '../more/confirm_sign_out.dart';
import '../navigation/unified_shell.dart';
import '../../state/workforce_scope.dart';
import 'package:flutter/material.dart';
import '../../state/app_scope.dart';
import '../navigation/main_shell.dart';
import 'login_screen.dart';

class CompanySelectionScreen extends StatelessWidget {
  const CompanySelectionScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus petshops'),
        actions: [
          TextButton(
            onPressed: () => confirmSignOut(context),
            child: const Text('Sair'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Selecione um petshop vinculado ao seu perfil. Apenas seus vínculos ativos aparecem aqui.',
          ),
          const SizedBox(height: 16),
          for (final company in controller.companies)
            Card(
              child: ListTile(
                title: Text(company.name),
                subtitle: Text(company.user.roleLabel),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: controller.busy
                    ? null
                    : () async {
                        final workforce = WorkforceScope.maybeOf(context);
                        final selected = controller.unified && workforce != null
                            ? await workforce.selectCompany(company.id)
                            : await controller.selectCompany(company.id);
                        if (selected && context.mounted) {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => controller.unified
                                  ? const UnifiedShell()
                                  : const MainShell(initialIndex: 2),
                            ),
                          );
                        } else if (context.mounted &&
                            controller.companies.isEmpty) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                            (_) => false,
                          );
                        }
                      },
              ),
            ),
          if (controller.busy) const Center(child: CircularProgressIndicator()),
          if (controller.error != null) Text(controller.error!),
        ],
      ),
    );
  }
}
