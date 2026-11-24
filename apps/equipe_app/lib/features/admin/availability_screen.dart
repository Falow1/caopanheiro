import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppContentCard;

import '../../core/app_theme.dart';
import '../../state/app_scope.dart';
import 'weekly_hours_editor.dart';

class AvailabilityScreen extends StatefulWidget {
  const AvailabilityScreen({super.key});
  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  String? _professionalId;
  final _periods = <String, List<String>>{
    'Segunda-feira': ['08:00 — 12:00', '13:00 — 18:00'],
    'Terça-feira': ['08:00 — 18:00'],
    'Quarta-feira': ['08:00 — 18:00'],
  };

  @override
  Widget build(BuildContext context) {
    if (AppScope.of(context).catalogOnly) {
      return const IntegratedAvailabilityScreen();
    }
    final professionals = AppScope.of(context).professionals;
    _professionalId ??= professionals.first.id;
    return Scaffold(
      appBar: AppBar(title: const Text('Disponibilidade')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _professionalId,
            decoration: const InputDecoration(labelText: 'Profissional'),
            items: professionals
                .map(
                  (item) =>
                      DropdownMenuItem(value: item.id, child: Text(item.name)),
                )
                .toList(),
            onChanged: (value) => setState(() => _professionalId = value),
          ),
          const SizedBox(height: 24),
          ..._periods.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppContentCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 9),
                    ...entry.value.map(
                      (period) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              size: 17,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(period),
                          ],
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () =>
                          setState(() => entry.value.add('14:00 — 18:00')),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Adicionar período'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Disponibilidade salva.')),
            ),
            child: const Text('Salvar disponibilidade'),
          ),
        ],
      ),
    );
  }
}
