import 'package:caopanheiro_contracts/caopanheiro_contracts.dart'
    show petServiceText;
import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppScreenTips, AppTourTarget;
import '../../core/screen_tips.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/models/pet.dart';
import '../../state/app_scope.dart';
import '../navigation/tutor_wide_layout.dart';
import '../pets/pet_card.dart';
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
        // One under the other on the phone; two per row on wide windows, the
        // cards of a row with the same height.
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = tutorWide(context) && constraints.maxWidth >= 560
                ? 2
                : 1;
            return PetCardGrid(
              columns: columns,
              children: [
                for (final pet in pets)
                  AppTourTarget(
                    id: TipTargets.bookingPet,
                    child: _SelectablePet(
                      pet: pet,
                      fill: columns > 1,
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
            );
          },
        ),
        const SizedBox(height: 12),
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
    this.fill = false,
  });
  final Pet pet;
  final bool selected;
  final VoidCallback onTap;
  final bool fill;

  /// Why the petshop does not serve the pet; then it cannot be chosen.
  final String? refusal;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: refusal == null ? selected : null,
    child: PetCard(
      pet: pet,
      fill: fill,
      selected: selected,
      dimmed: refusal != null,
      onTap: refusal == null ? onTap : null,
      trailing: refusal == null ? PetCheck(selected: selected) : null,
      notes: [
        if (refusal != null) ...[
          const SizedBox(height: 4),
          Text(refusal!, style: const TextStyle(color: AppColors.warning)),
        ],
      ],
    ),
  );
}
