import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppOfflineBanner;
import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../domain/models/scheduling_policy.dart';
import '../../state/app_scope.dart';

class WeeklyHoursEditor extends StatefulWidget {
  const WeeklyHoursEditor({super.key, this.professional});
  final Professional? professional;
  @override
  State<WeeklyHoursEditor> createState() => _WeeklyHoursEditorState();
}

class _WeeklyHoursEditorState extends State<WeeklyHoursEditor> {
  static const labels = [
    'Segunda-feira',
    'Terça-feira',
    'Quarta-feira',
    'Quinta-feira',
    'Sexta-feira',
    'Sábado',
    'Domingo',
  ];
  final _periods = List.generate(7, (_) => TextEditingController());
  final _zone = TextEditingController();
  final _interval = TextEditingController();
  bool _loaded = false;
  bool _loading = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    for (final controller in _periods) {
      controller.dispose();
    }
    _zone.dispose();
    _interval.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final controller = AppScope.of(context);
    final success = await controller.loadSchedulingPolicy();
    if (!mounted) return;
    if (success) {
      final policy = controller.schedulingPolicy;
      _zone.text = policy.timeZone;
      _interval.text = '${policy.slotMinutes}';
      final days = widget.professional?.availability ?? policy.days;
      for (var i = 0; i < 7; i++) {
        final entries =
            days[i + 1] ??
            (!policy.configured && i < 6
                ? [const WorkPeriod(480, 1080)]
                : <WorkPeriod>[]);
        _periods[i].text = entries
            .map(
              (period) =>
                  '${WorkPeriod.label(period.start)}-${WorkPeriod.label(period.end)}',
            )
            .join(', ');
      }
    }
    setState(() {
      _loading = false;
      _loaded = success;
      _error = success ? null : controller.error;
    });
  }

  Future<void> _save() async {
    final controller = AppScope.of(context);
    if ((controller.user?.isManager != true ||
            controller.user?.canManage(
                  widget.professional == null ? 'SETTINGS' : 'PROFESSIONALS',
                ) !=
                true) ||
        controller.catalogOffline ||
        controller.busy) {
      return;
    }
    try {
      final days = <int, List<WorkPeriod>>{};
      for (var i = 0; i < 7; i++) {
        final value = _periods[i].text.trim();
        days[i + 1] = value.isEmpty
            ? []
            : value.split(',').map((entry) {
                final bounds = entry.trim().split('-');
                if (bounds.length != 2) {
                  throw const FormatException(
                    'Use períodos como 08:00-12:00, 13:00-18:00.',
                  );
                }
                return WorkPeriod(
                  WorkPeriod.parse(bounds[0]),
                  WorkPeriod.parse(bounds[1]),
                );
              }).toList();
      }
      bool saved;
      final original = widget.professional;
      if (original != null) {
        saved = await controller.saveProfessional(
          Professional(
            id: original.id,
            name: original.name,
            specialty: original.specialty,
            email: original.email,
            active: original.active,
            availability: days,
          ),
        );
      } else {
        final interval = int.tryParse(_interval.text);
        if (interval == null) {
          throw const FormatException('Informe o intervalo em minutos.');
        }
        saved = await controller.saveSchedulingPolicy(
          SchedulingPolicy(
            configured: true,
            timeZone: _zone.text.trim(),
            slotMinutes: interval,
            days: days,
          ),
        );
      }
      if (!mounted) return;
      if (saved) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Horários salvos.')));
        Navigator.pop(context);
      } else {
        setState(() => _error = controller.error);
      }
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    if ((controller.user?.isManager != true ||
        controller.user?.canManage(
              widget.professional == null ? 'SETTINGS' : 'PROFESSIONALS',
            ) !=
            true)) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Funcionamento e disponibilidade recorrente são definidos pelo gestor.',
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.professional == null
              ? 'Horário de funcionamento'
              : 'Disponibilidade · ${widget.professional!.name}',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Informe até quatro períodos por dia, separados por vírgula. Deixe vazio nos dias sem atendimento. Exemplo: 08:00-12:00, 13:00-18:00.',
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (!_loaded && !_loading)
            OutlinedButton(
              onPressed: _load,
              child: const Text('Tentar novamente'),
            ),
          if (_loaded) ...[
            if (widget.professional == null) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _zone,
                decoration: const InputDecoration(
                  labelText: 'Fuso horário da empresa',
                  helperText:
                      'Vem do estado do cadastro. Troque só se a cidade usar '
                      'outro fuso, como America/Noronha ou America/Eirunepe.',
                  helperMaxLines: 2,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _interval,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Intervalo entre opções de horário (min)',
                ),
              ),
            ],
            for (var i = 0; i < 7; i++)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: TextField(
                  controller: _periods[i],
                  enabled: !controller.catalogOffline,
                  decoration: InputDecoration(
                    labelText: labels[i],
                    hintText: 'Fechado',
                  ),
                ),
              ),
            const SizedBox(height: 20),
            if (controller.catalogOffline)
              const AppOfflineBanner(
                message:
                    'Consulta offline · conecte-se e atualize os dados para alterar.',
              ),
            FilledButton(
              onPressed: controller.busy || controller.catalogOffline
                  ? null
                  : _save,
              child: const Text('Salvar horários'),
            ),
          ],
        ],
      ),
    );
  }
}

class IntegratedAvailabilityScreen extends StatelessWidget {
  const IntegratedAvailabilityScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    if ((controller.user?.isManager != true ||
        controller.user?.canManage('PROFESSIONALS') != true)) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Funcionamento e disponibilidade recorrente são definidos pelo gestor.',
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Disponibilidade')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (controller.professionals.isEmpty)
            const Text(
              'Cadastre um profissional para configurar sua disponibilidade.',
            ),
          for (final professional in controller.professionals)
            Card(
              child: ListTile(
                title: Text(professional.name),
                subtitle: Text(professional.active ? 'Ativo' : 'Inativo'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        WeeklyHoursEditor(professional: professional),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
