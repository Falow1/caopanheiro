import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show showAppConfirmation;
import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';
import '../../state/app_scope.dart';

/// "Raças sugeridas": names typed in "Outra raça" when the breed was not on
/// the list. Read when the screen opens; nothing here changes a pet.
class BreedSuggestionsScreen extends StatefulWidget {
  const BreedSuggestionsScreen({super.key});
  @override
  State<BreedSuggestionsScreen> createState() => _BreedSuggestionsScreenState();
}

class _BreedSuggestionsScreenState extends State<BreedSuggestionsScreen> {
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final loaded = await AppScope.of(context).loadBreedSuggestions();
    if (mounted) setState(() => _loaded = loaded);
  }

  Future<void> _evaluated(BreedSuggestion item) async {
    final controller = AppScope.of(context);
    final confirmed = await showAppConfirmation(
      context,
      title: 'Marcar "${item.name}" como avaliada?',
      message:
          'A sugestão sai desta lista. Para a raça entrar na lista do app, ela '
          'precisa ser incluída numa nova versão.',
      confirmLabel: 'Marcar como avaliada',
    );
    if (!confirmed || !mounted) return;
    await controller.removeBreedSuggestion(item.id);
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    if (controller.admin == null) return const SizedBox.shrink();
    final items = controller.breedSuggestions;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Raças sugeridas'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: controller.busy ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Raças que tutores e equipes não acharam na lista e digitaram em '
              '"Outra raça". Vem só o nome e a espécie, sem pet, tutor ou '
              'petshop. As mais digitadas aparecem primeiro.',
            ),
            if (controller.error != null) ...[
              const SizedBox(height: 12),
              Text(
                controller.error!,
                style: const TextStyle(color: AppColors.danger),
              ),
            ],
            const SizedBox(height: 16),
            if (!_loaded && controller.busy)
              const Center(child: CircularProgressIndicator())
            else if (items.isEmpty)
              const Text('Nenhuma raça sugerida no momento.')
            else
              for (final item in items)
                Card(
                  child: ListTile(
                    title: Text(item.name),
                    subtitle: Text(
                      [
                        item.species,
                        item.count == 1 ? '1 vez' : '${item.count} vezes',
                        if (item.lastAt != null)
                          'última em ${date(item.lastAt!)}',
                      ].join(' · '),
                    ),
                    trailing: IconButton(
                      tooltip: 'Marcar como avaliada',
                      onPressed: controller.busy
                          ? null
                          : () => _evaluated(item),
                      icon: const Icon(Icons.done_rounded),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
