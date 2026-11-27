import 'package:caopanheiro_contracts/caopanheiro_contracts.dart'
    show petServiceText;
import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppScreenTips, AppTourTarget;
import '../../core/screen_tips.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppDimensions;

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../domain/models/pet.dart';
import '../../state/app_scope.dart';
import '../appointments/history_screen.dart';
import '../home/read_only_company.dart';
import '../navigation/tutor_shell_scope.dart';
import '../navigation/tutor_wide_layout.dart';
import 'pet_card.dart';
import 'pet_form_screen.dart';

class PetsScreen extends StatelessWidget {
  const PetsScreen({super.key});

  @override
  Widget build(BuildContext context) => AppScreenTips(
    screen: TipScreens.pets,
    tips: tutorTips(context, TutorTips.pets),
    ready: !AppScope.of(context).busy,
    child: _content(context),
  );

  Widget _content(BuildContext context) {
    final pets = AppScope.of(context).pets;
    final wide = tutorWide(context);
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Meus pets', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          '${pets.length} ${pets.length == 1 ? 'companheiro cadastrado' : 'companheiros cadastrados'}',
        ),
      ],
    );
    void add() => AppScope.of(context).companyReadOnly
        ? showReadOnlyCompany(context)
        : Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PetFormScreen()),
          );
    if (!wide) {
      return Scaffold(
        body: SafeArea(
          child: PageBody(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                title,
                const SizedBox(height: 24),
                PetCardGrid(
                  columns: 1,
                  children: [
                    for (final pet in pets)
                      AppTourTarget(
                        id: TipTargets.petsCard,
                        child: _PetTile(pet: pet),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                AppTourTarget(
                  id: TipTargets.petsAdd,
                  child: OutlinedButton.icon(
                    onPressed: add,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Adicionar pet'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    // Two columns; three when the page has its whole width.
    final columns =
        tutorContentWidth(context) >= AppDimensions.tutorDesktopPageWidth
        ? 3
        : 2;
    return Scaffold(
      body: SafeArea(
        child: TutorPageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: title),
                  const TutorRefreshButton(),
                  const SizedBox(width: 10),
                  AppTourTarget(
                    id: TipTargets.petsAdd,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                      ),
                      onPressed: add,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Adicionar pet'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // The cards of a row share the height, the history at the bottom.
              PetCardGrid(
                columns: columns,
                gap: 16,
                children: [
                  for (final pet in pets)
                    AppTourTarget(
                      id: TipTargets.petsCard,
                      child: _PetTile(pet: pet, fill: true),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PetTile extends StatelessWidget {
  const _PetTile({required this.pet, this.fill = false});
  final Pet pet;

  /// In the grid of wide windows, the card takes the height of its row.
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final reason = pet.serviceReason;
    final phone = controller.companyContactPhone;
    return PetCard(
      pet: pet,
      fill: fill,
      onTap: () => controller.companyReadOnly
          ? showReadOnlyCompany(context)
          : Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PetFormScreen(pet: pet)),
            ),
      trailing: const Icon(
        Icons.edit_outlined,
        size: 20,
        color: AppColors.muted,
      ),
      notes: [
        if (pet.breedPending)
          const Text(
            'Toque para escolher a raça na lista.',
            style: TextStyle(color: AppColors.muted),
          ),
        // Not served now: the message only, never the reason the team wrote
        // for "Não atender este pet".
        if (reason != null) ...[
          const SizedBox(height: 6),
          Text(
            petServiceText(
              reason,
              petName: pet.name,
              breed: pet.breedEntry,
              petshop: controller.companyName,
              tutor: true,
            ),
            style: const TextStyle(color: AppColors.warning),
          ),
          if (phone.isNotEmpty)
            Text(
              'Telefone do petshop: $phone',
              style: const TextStyle(color: AppColors.warning),
            ),
        ],
      ],
      // The visits of this pet only, apart from the full history.
      footer: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: ValueKey('pet-history-${pet.id}'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HistoryScreen(petId: pet.id, petName: pet.name),
              ),
            ),
            icon: const Icon(Icons.history_rounded),
            label: Text('Histórico de ${pet.name}'),
          ),
        ),
      ),
    );
  }
}
