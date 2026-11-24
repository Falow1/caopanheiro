import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppContentCard;

import '../../core/app_theme.dart';
import '../../state/app_scope.dart';
import 'weekly_hours_editor.dart';

class BusinessHoursScreen extends StatefulWidget {
  const BusinessHoursScreen({super.key});
  @override
  State<BusinessHoursScreen> createState() => _BusinessHoursScreenState();
}

class _BusinessHoursScreenState extends State<BusinessHoursScreen> {
  final Map<String, bool> _days = {
    'Segunda-feira': true,
    'Terça-feira': true,
    'Quarta-feira': true,
    'Quinta-feira': true,
    'Sexta-feira': true,
    'Sábado': true,
    'Domingo': false,
  };
  bool _editing = false;

  @override
  Widget build(BuildContext context) => AppScope.of(context).catalogOnly
      ? const WeeklyHoursEditor()
      : Scaffold(
          appBar: AppBar(
            title: const Text('Horário de funcionamento'),
            actions: [
              TextButton(
                onPressed: () => setState(() => _editing = !_editing),
                child: Text(_editing ? 'Cancelar' : 'Editar'),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
            children: [
              const Text(
                'Defina quando o estabelecimento recebe agendamentos.',
              ),
              const SizedBox(height: 20),
              ..._days.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppContentCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.key,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                entry.value ? '08:00 — 18:00' : 'Fechado',
                                style: TextStyle(
                                  color: entry.value
                                      ? AppColors.primary
                                      : AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_editing)
                          Switch(
                            value: entry.value,
                            onChanged: (value) =>
                                setState(() => _days[entry.key] = value),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_editing) ...[
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    setState(() => _editing = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Horários salvos.')),
                    );
                  },
                  child: const Text('Salvar horários'),
                ),
              ],
            ],
          ),
        );
}
