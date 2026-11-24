import 'package:flutter/material.dart';
import '../../domain/models.dart';
import '../../state/app_scope.dart';
import 'staff_unlink_dialog.dart';
import 'workforce_members_screen.dart';

class ProfessionalFormScreen extends StatelessWidget {
  const ProfessionalFormScreen({super.key, this.professional});
  final Professional? professional;
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context), p = professional;
    if (p == null) return const StaffInviteFormScreen(professional: true);
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil profissional')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(p.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(p.specialty),
            const SizedBox(height: 8),
            Text(p.active ? 'Vinculado ao petshop' : 'Desvinculado'),
            const SizedBox(height: 20),
            const Text(
              'Os dados deste perfil são preenchidos pelo profissional. O gestor administra somente o vínculo e as configurações da operação.',
            ),
            if (c.user?.canManagePeople == true) ...[
              const SizedBox(height: 24),
              if (p.active &&
                  c.companies
                          .where((company) => company.user.isPrincipal)
                          .length >
                      1)
                OutlinedButton.icon(
                  onPressed: c.busy || c.readOnly
                      ? null
                      : () async {
                          final source = c.company?.id;
                          final members = await c.workforceMembers();
                          if (!context.mounted ||
                              c.company?.id != source ||
                              members == null) {
                            return;
                          }
                          final matching = members
                              .where(
                                (member) =>
                                    member['professionalId'] == p.id &&
                                    member['active'] == true,
                              )
                              .toList();
                          if (matching.length != 1) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Este cadastro precisa de vínculo ativo para ser transferido.',
                                ),
                              ),
                            );
                            return;
                          }
                          final changed = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => WorkforceMemberAccessScreen(
                                member: matching.single,
                                management: false,
                              ),
                            ),
                          );
                          if (context.mounted && changed == true) {
                            Navigator.pop(context);
                          }
                        },
                  icon: const Icon(Icons.drive_file_move_outlined),
                  label: const Text('Funções e transferência de empresa'),
                ),
              if (p.active)
                OutlinedButton.icon(
                  onPressed: c.busy || c.readOnly
                      ? null
                      : () async {
                          if (await unlinkStaffFromPetshop(
                                context,
                                name: p.name,
                                target: {'professionalId': p.id},
                              ) &&
                              context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                  icon: const Icon(Icons.person_remove_outlined),
                  label: const Text('Desvincular do petshop'),
                )
              else
                FilledButton(
                  onPressed: c.busy || c.readOnly
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                StaffInviteFormScreen(professionalId: p.id),
                          ),
                        ),
                  child: const Text('Convidar novamente'),
                ),
            ],
            if (c.error != null) Text(c.error!),
          ],
        ),
      ),
    );
  }
}
