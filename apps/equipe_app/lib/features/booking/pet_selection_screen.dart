import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppRadii, AppTextStyles;

import '../../core/app_theme.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';
import '../pets/pet_form_screen.dart';
import 'booking_draft.dart';
import 'service_selection_screen.dart';

class PetSelectionScreen extends StatefulWidget {
  const PetSelectionScreen({super.key, required this.customer});
  final Customer customer;
  @override
  State<PetSelectionScreen> createState() => _PetSelectionScreenState();
}

class _PetSelectionScreenState extends State<PetSelectionScreen> {
  final Set<String> _selected = {};
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Selecionar pets')),
    body: Column(
      children: [
        Expanded(
          child: PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('2 de 5 · Pets', style: AppTextStyles.primaryStrong),
                const SizedBox(height: 14),
                Text(
                  'Quais pets de ${widget.customer.name}?',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 20),
                ...widget.customer.pets.map((pet) {
                  final selected = _selected.contains(pet.id);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      color: selected ? AppColors.mint : AppColors.paper,
                      child: CheckboxListTile(
                        value: selected,
                        onChanged: (_) => setState(
                          () => selected
                              ? _selected.remove(pet.id)
                              : _selected.add(pet.id),
                        ),
                        secondary: Text(
                          pet.emoji,
                          style: const TextStyle(fontSize: 30),
                        ),
                        title: Text(
                          pet.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        subtitle: Text(pet.breed),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadii.r20,
                        ),
                      ),
                    ),
                  );
                }),
                TextButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            PetFormScreen(customerId: widget.customer.id),
                      ),
                    );
                    if (mounted) setState(() {});
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Novo pet'),
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 13, 20, 20),
          decoration: const BoxDecoration(
            color: AppColors.paper,
            border: Border(top: BorderSide(color: AppColors.line)),
          ),
          child: SafeArea(
            top: false,
            child: FilledButton(
              onPressed: _selected.isEmpty
                  ? null
                  : () {
                      final draft = BookingDraft(customer: widget.customer);
                      draft.pets.addAll(
                        widget.customer.pets.where(
                          (pet) => _selected.contains(pet.id),
                        ),
                      );
                      for (final pet in draft.pets) {
                        draft.services[pet.id] = {};
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ServiceSelectionScreen(draft: draft),
                        ),
                      );
                    },
              child: const Text('Continuar'),
            ),
          ),
        ),
      ],
    ),
  );
}
