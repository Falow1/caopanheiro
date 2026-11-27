import 'package:caopanheiro_contracts/caopanheiro_contracts.dart'
    show petServiceText;
import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppScreenTips, AppTourTarget;
import '../../core/screen_tips.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppPetIcon, AppRadii;

import '../../core/theme/app_theme.dart';
import '../../domain/models/pet.dart';
import '../../state/app_scope.dart';
import '../pets/pet_form_screen.dart';
import 'booking_draft.dart';
import 'service_selection_screen.dart';
import 'widgets/booking_frame.dart';

class PetSelectionScreen extends StatefulWidget {
  const PetSelectionScreen({super.key});
  @override
  State<PetSelectionScreen> createState() => _PetSelectionScreenState();
}

class _PetSelectionScreenState extends State<PetSelectionScreen> {
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    // The steps count the transport when the petshop offers it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.of(context).loadTransportOffer();
    });
  }

  void _continue() {
    final pets = AppScope.of(
      context,
    ).pets.where((pet) => pet.served && _selected.contains(pet.id)).toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ServiceSelectionScreen(
          draft: BookingDraft(
            pets: pets,
            companyId: AppScope.of(context).companyId,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AppScreenTips(
    screen: TipScreens.bookingPets,
    tips: tutorTips(context, TutorTips.bookingPets),
    child: _content(context),
  );

  Widget _content(BuildContext context) {
    final controller = AppScope.of(context);
    final pets = controller.pets;
    return BookingFrame(
      title: 'Novo agendamento',
      step: 0,
      stepCount: bookingStepCount(context),
      stepsTip: true,
      summary: BookingSummary(
        pets: pets.where((pet) => _selected.contains(pet.id)).toList(),
        showProfessional: AppScope.of(context).integrated,
      ),
      summaryTip: TipTargets.bookingSummary,
      primary: FilledButton(
        onPressed: _selected.isEmpty ? null : _continue,
        child: const Text('Continuar'),
      ),
      back: TextButton(
        onPressed: () => Navigator.maybePop(context),
        child: const Text('Voltar'),
      ),
      children: [
        Text(
          'Quem vem com a gente?',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text('Você pode selecionar mais de um pet.'),
        const SizedBox(height: 24),
        // One under the other on the phone; two per row on wide windows.
        BookingGrid(
          children: [
            for (final pet in pets)
              AppTourTarget(
                id: TipTargets.bookingPet,
                child: _SelectablePet(
                  pet: pet,
                  selected: _selected.contains(pet.id),
                  // A pet the petshop does not serve cannot be booked; the
                  // server refuses it too.
                  refusal: pet.serviceReason == null
                      ? null
                      : petServiceText(
                          pet.serviceReason!,
                          petName: pet.name,
                          breed: pet.breedEntry,
                          petshop: controller.companyName,
                          tutor: true,
                        ),
                  onTap: () => setState(
                    () => _selected.contains(pet.id)
                        ? _selected.remove(pet.id)
                        : _selected.add(pet.id),
                  ),
                ),
              ),
          ],
        ),
        AppTourTarget(
          id: TipTargets.bookingOtherPet,
          child: TextButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PetFormScreen()),
              );
              if (mounted) setState(() {});
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Cadastrar outro pet'),
          ),
        ),
      ],
    );
  }
}

class _SelectablePet extends StatelessWidget {
  const _SelectablePet({
    required this.pet,
    required this.selected,
    required this.onTap,
    this.refusal,
  });
  final Pet pet;
  final bool selected;
  final VoidCallback onTap;

  /// Why the petshop does not serve the pet; then it cannot be chosen.
  final String? refusal;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.mint : AppColors.paper,
    shape: RoundedRectangleBorder(
      borderRadius: AppRadii.r20,
      side: BorderSide(
        color: selected ? AppColors.primary : AppColors.line,
        width: selected ? 1.5 : 1,
      ),
    ),
    child: InkWell(
      onTap: refusal == null ? onTap : null,
      borderRadius: AppRadii.r20,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Opacity(
              opacity: refusal == null ? 1 : 0.45,
              child: AppPetIcon(
                icon: pet.breedIcon,
                size: 52,
                semanticLabel: pet.breed,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pet.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text('${pet.species} · ${pet.breed}'),
                  if (refusal != null)
                    Text(
                      refusal!,
                      style: const TextStyle(color: AppColors.warning),
                    ),
                ],
              ),
            ),
            if (refusal == null)
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? AppColors.primary : AppColors.muted,
                  ),
                ),
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: Colors.white,
                      )
                    : null,
              ),
          ],
        ),
      ),
    ),
  );
}
