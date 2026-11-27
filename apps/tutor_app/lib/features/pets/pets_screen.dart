import 'package:caopanheiro_contracts/caopanheiro_contracts.dart'
    show petServiceText;
import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppScreenTips, AppTourTarget;
import '../../core/screen_tips.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppDimensions, AppPetIcon, AppRadii;

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../domain/models/pet.dart';
import '../../state/app_scope.dart';
import '../appointments/history_screen.dart';
import '../home/read_only_company.dart';
import '../navigation/tutor_shell_scope.dart';
import '../navigation/tutor_wide_layout.dart';
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
                ...pets.map(
                  (pet) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppTourTarget(
                      id: TipTargets.petsCard,
                      child: _PetTile(pet: pet),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
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
              LayoutBuilder(
                builder: (context, constraints) {
                  final width =
                      (constraints.maxWidth - 16 * (columns - 1)) / columns;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      for (final pet in pets)
                        SizedBox(
                          width: width,
                          child: AppTourTarget(
                            id: TipTargets.petsCard,
                            child: _PetTile(pet: pet, margin: EdgeInsets.zero),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PetTile extends StatelessWidget {
  const _PetTile({required this.pet, this.margin});
  final Pet pet;

  /// The grid of wide windows spaces the cards itself.
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final reason = pet.serviceReason;
    final phone = controller.companyContactPhone;
    return Card(
      margin: margin,
      child: InkWell(
        borderRadius: AppRadii.r22,
        onTap: () => controller.companyReadOnly
            ? showReadOnlyCompany(context)
            : Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PetFormScreen(pet: pet)),
              ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // The icon of the breed; the paw of the brand when unknown.
                  AppPetIcon(
                    icon: pet.breedIcon,
                    size: 62,
                    semanticLabel: pet.breed,
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pet.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text('${pet.species} · ${pet.breed}'),
                        if (pet.breedPending)
                          const Text(
                            'Toque para escolher a raça na lista.',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        // Not served now: the message only, never the reason the
                        // team wrote for "Não atender este pet".
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
                    ),
                  ),
                  const Icon(
                    Icons.edit_outlined,
                    size: 20,
                    color: AppColors.muted,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // The visits of this pet only, apart from the full history.
              TextButton.icon(
                key: ValueKey('pet-history-${pet.id}'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        HistoryScreen(petId: pet.id, petName: pet.name),
                  ),
                ),
                icon: const Icon(Icons.history_rounded),
                label: Text('Histórico de ${pet.name}'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
