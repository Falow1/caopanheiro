import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppTextStyles;

import '../../core/utils/formatters.dart';
import '../../domain/models/pet.dart';
import '../../domain/models/service.dart';
import '../../state/app_scope.dart';
import 'booking_draft.dart';
import 'schedule_screen.dart';
import 'widgets/booking_frame.dart';

class ServiceSelectionScreen extends StatefulWidget {
  const ServiceSelectionScreen({super.key, required this.draft});
  final BookingDraft draft;
  @override
  State<ServiceSelectionScreen> createState() => _ServiceSelectionScreenState();
}

class _ServiceSelectionScreenState extends State<ServiceSelectionScreen> {
  void _toggle(Pet pet, PetService service) {
    setState(() {
      final selected = widget.draft.selectedServices[pet.id]!;
      selected.any((item) => item.id == service.id)
          ? selected.removeWhere((item) => item.id == service.id)
          : selected.add(service);
    });
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context).services;
    final draft = widget.draft;
    return BookingFrame(
      title: 'Escolher serviços',
      step: 1,
      stepCount: bookingStepCount(context, reschedule: draft.reschedule),
      // The phone keeps the count, the time and the total over the button.
      phoneBar: BookingPhoneBar.sheet,
      phoneBottom: 150,
      barNote: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${draft.totalServices} ${draft.totalServices == 1 ? 'serviço' : 'serviços'}\n${draft.totalDuration} min estimados',
                style: AppTextStyles.captionMuted,
              ),
            ),
            Text(
              formatMoney(draft.totalPrice),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      ),
      summary: BookingSummary(
        pets: draft.pets,
        services: draft.selectedServices,
        showProfessional: AppScope.of(context).integrated,
      ),
      primary: FilledButton(
        onPressed: draft.eachPetHasService
            ? () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ScheduleScreen(draft: draft)),
              )
            : null,
        child: const Text('Continuar'),
      ),
      back: TextButton(
        onPressed: () => Navigator.maybePop(context),
        child: const Text('Voltar'),
      ),
      children: [
        Text(
          'O que cada pet precisa?',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text('Escolha pelo menos um serviço para cada pet.'),
        const SizedBox(height: 26),
        for (final pet in draft.pets)
          Padding(
            padding: const EdgeInsets.only(bottom: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(pet.emoji, style: const TextStyle(fontSize: 25)),
                    const SizedBox(width: 9),
                    Text(
                      pet.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // One under the other on the phone; two per row on wide
                // windows.
                BookingGrid(
                  gap: 10,
                  children: [
                    for (final service in services)
                      _ServiceTile(
                        service: service,
                        selected: draft.selectedServices[pet.id]!.any(
                          (item) => item.id == service.id,
                        ),
                        onTap: () => _toggle(pet, service),
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.service,
    required this.selected,
    required this.onTap,
  });
  final PetService service;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => BookingCheckCard(
    title: service.name,
    subtitle: '${service.durationMinutes} min · ${service.description}',
    selected: selected,
    onTap: onTap,
    trailing: Text(formatMoney(service.price), style: AppTextStyles.emphasis),
  );
}
