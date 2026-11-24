import 'package:flutter/material.dart';
import '../../core/widgets.dart';
import '../../state/app_scope.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});
  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  bool _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && AppScope.of(context).admin != null) {
          AppScope.of(context).loadHealth();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final result = controller.health;
    return Scaffold(
      appBar: AppBar(title: const Text('Saúde da plataforma')),
      body: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (result == null)
              const Text('Nenhum diagnóstico de infraestrutura disponível.'),
            if (result != null) ...[
              Text(
                result.ready
                    ? 'Serviços disponíveis'
                    : 'Há serviços indisponíveis',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                '${result.environment} · Versão ${result.version ?? 'não informada'}',
              ),
              const SizedBox(height: 16),
              for (final entry in [
                ('functions', 'Operações'),
                ('firestore', 'Banco de dados'),
                ('auth', 'Autenticação'),
              ])
                Card(
                  child: ListTile(
                    title: Text(entry.$2),
                    subtitle: Text(
                      result.services[entry.$1]!.available
                          ? 'Disponível'
                          : 'Indisponível',
                    ),
                    trailing: result.services[entry.$1]!.latencyMs == null
                        ? null
                        : Text('${result.services[entry.$1]!.latencyMs} ms'),
                  ),
                ),
              const Card(
                child: ListTile(
                  title: Text('Fila de processamento'),
                  subtitle: Text('Não configurada'),
                ),
              ),
              Text('Verificação: ${result.checkedAt}'),
            ],
            if (controller.error != null) Text(controller.error!),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: controller.busy ? null : controller.loadHealth,
              child: const Text('Verificar serviços'),
            ),
          ],
        ),
      ),
    );
  }
}
