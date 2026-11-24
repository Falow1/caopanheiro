import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppRadii, AppTextStyles;

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../state/app_scope.dart';
import 'booking_draft.dart';
import 'schedule_selection_screen.dart';

class ServiceSelectionScreen extends StatefulWidget {
  const ServiceSelectionScreen({super.key, required this.draft});
  final BookingDraft draft;
  @override
  State<ServiceSelectionScreen> createState() => _ServiceSelectionScreenState();
}

class _ServiceSelectionScreenState extends State<ServiceSelectionScreen> {
  @override
  Widget build(BuildContext context) {
    final available = AppScope.of(
      context,
    ).services.where((item) => item.active).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Selecionar serviços')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 150),
        children: [
          const Text('3 de 5 · Serviços', style: AppTextStyles.primaryStrong),
          const SizedBox(height: 14),
          Text(
            'O que será feito?',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 5),
          const Text('Escolha pelo menos um serviço para cada pet.'),
          const SizedBox(height: 24),
          ...widget.draft.pets.map(
            (pet) => Padding(
              padding: const EdgeInsets.only(bottom: 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${pet.emoji}  ${pet.name}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  ...available.map((service) {
                    final selected = widget.draft.services[pet.id]!.any(
                      (item) => item.id == service.id,
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: Card(
                        color: selected ? AppColors.mint : AppColors.paper,
                        child: CheckboxListTile(
                          value: selected,
                          onChanged: (_) => setState(
                            () => selected
                                ? widget.draft.services[pet.id]!.removeWhere(
                                    (item) => item.id == service.id,
                                  )
                                : widget.draft.services[pet.id]!.add(service),
                          ),
                          title: Text(
                            service.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          subtitle: Text(
                            '${service.duration} min · ${money(service.price)}',
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadii.r20,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(20, 13, 20, 18),
        decoration: const BoxDecoration(
          color: AppColors.paper,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${widget.draft.allServices.length} serviços · ${widget.draft.duration} min',
                  ),
                  Text(
                    money(widget.draft.price),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: widget.draft.validServices
                    ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ScheduleSelectionScreen(draft: widget.draft),
                        ),
                      )
                    : null,
                child: const Text('Continuar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
