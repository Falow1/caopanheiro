import 'package:caopanheiro_contracts/caopanheiro_contracts.dart'
    show petServiceText;
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppButtonStyles, AppColors, AppPetIcon, showAppConfirmation;
import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../state/app_scope.dart';
import '../pets/breed_field.dart' show PetTextDialog;
import '../pets/pet_form_screen.dart';
import 'customer_pet_notes_screen.dart';

/// Pet of the customer screen: breed icon, whether the petshop serves it and,
/// for the team, "Não atender este pet" / "Voltar a atender".
class CustomerPetCard extends StatelessWidget {
  const CustomerPetCard({
    super.key,
    required this.customerId,
    required this.pet,
    this.tutorManaged = false,
  });
  final String customerId;
  final Pet pet;

  /// The tutor registered in the app: only they edit the pet.
  final bool tutorManaged;

  String? get _warning {
    final reason = pet.serviceReason;
    if (reason == null) return null;
    final block = pet.block;
    if (block != null) {
      final by = block.createdByName == null ? '' : ' (${block.createdByName})';
      return 'Não atender este pet$by: ${block.reason}';
    }
    return petServiceText(reason, petName: pet.name, breed: pet.breedEntry);
  }

  Future<void> _block(BuildContext context) async {
    final controller = AppScope.of(context);
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => PetTextDialog(
        title: 'Não atender ${pet.name}',
        message:
            'O pet não poderá ser agendado, pelo app ou pela equipe. O tutor vê '
            'só um aviso para falar com o petshop; o motivo fica para a equipe. '
            'Agendamentos já marcados continuam valendo.',
        label: 'Motivo (só a equipe vê)',
        initial: pet.block?.reason ?? '',
        maxLength: 300,
        maxLines: 3,
        minLength: 3,
        confirmLabel: 'Não atender',
      ),
    );
    if (reason == null || !context.mounted) return;
    final future = await controller.blockPet(customerId, pet.id, reason);
    if (future == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          future == 0
              ? '${pet.name} não será atendido pelo app.'
              : '${pet.name} não será atendido em novos agendamentos. '
                    '${future == 1 ? 'O agendamento já marcado continua' : 'Os $future agendamentos já marcados continuam'} valendo.',
        ),
      ),
    );
  }

  Future<void> _unblock(BuildContext context) async {
    final controller = AppScope.of(context);
    final confirmed = await showAppConfirmation(
      context,
      title: 'Voltar a atender ${pet.name}?',
      message:
          'O pet volta a poder ser agendado, se a regra de pets atendidos permitir.',
      confirmLabel: 'Voltar a atender',
    );
    if (!confirmed || !context.mounted) return;
    await controller.unblockPet(customerId, pet.id);
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final manager =
        !controller.catalogOffline && controller.user!.canManage('CUSTOMERS');
    final editable = manager && !tutorManaged;
    final blockable = manager && controller.supportsPetService;
    final warning = _warning;
    final breed = pet.breedEntry;
    void edit() => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PetFormScreen(customerId: customerId, pet: pet),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              onTap: editable ? edit : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 7,
              ),
              leading: AppPetIcon(
                icon: pet.breedIcon,
                size: 48,
                semanticLabel: pet.breed,
              ),
              title: Text(
                pet.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    breed?.species == 'Gato' || pet.species == 'Gato'
                        ? '${pet.species} · ${pet.breed}'
                        : '${pet.species} · ${pet.breed} · Porte ${pet.size}',
                  ),
                  if (pet.breedPending)
                    const Text(
                      'Raça a confirmar na lista.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  if (tutorManaged)
                    const Text(
                      'Dados mantidos pelo tutor no app.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  if (warning != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.block_rounded,
                            size: 16,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              warning,
                              style: const TextStyle(color: AppColors.warning),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              trailing: editable
                  ? IconButton(
                      tooltip: 'Editar pet',
                      onPressed: edit,
                      icon: const Icon(Icons.edit_outlined),
                    )
                  : null,
            ),
            if (controller.petInternalNotesAvailable)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => CustomerPetNotesScreen(
                        customerId: customerId,
                        pet: pet,
                        sessionKey: controller.sessionKey,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.sticky_note_2_outlined),
                  label: const Text('Observações internas'),
                ),
              ),
            // The decision of not serving stays in sight, not in a menu.
            if (blockable)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: pet.block == null
                    ? OutlinedButton.icon(
                        key: ValueKey('block-pet-${pet.id}'),
                        style: AppButtonStyles.dangerOutlined,
                        onPressed: () => _block(context),
                        icon: const Icon(Icons.block_rounded),
                        label: const Text('Não atender este pet'),
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: FilledButton.tonalIcon(
                              key: ValueKey('unblock-pet-${pet.id}'),
                              onPressed: () => _unblock(context),
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Voltar a atender'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => _block(context),
                            child: const Text('Mudar motivo'),
                          ),
                        ],
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
