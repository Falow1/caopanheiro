import 'package:caopanheiro_contracts/caopanheiro_contracts.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppColors, AppContentCard, AppPetIcon, AppScreenTips, AppTourTarget;
import 'package:flutter/material.dart';

import '../../core/screen_tips.dart';
import '../../core/widgets.dart';
import '../../domain/models/team_company.dart';
import '../../state/app_scope.dart';

/// "Pets atendidos" (Mais → Funcionamento): which dogs, cats and puppies the
/// petshop serves. The rule is kept apart from the customers: a pet out of it
/// stays in the record, with a warning, and cannot be booked.
class PetPolicyScreen extends StatefulWidget {
  const PetPolicyScreen({super.key});
  @override
  State<PetPolicyScreen> createState() => _PetPolicyScreenState();
}

class _PetPolicyScreenState extends State<PetPolicyScreen> {
  PetPolicy? _policy;
  final Set<String> _alsoIn = {};
  bool _tried = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _policy ??= AppScope.of(context).petPolicy;
  }

  PetPolicy get _value => _policy!;
  void _set(PetPolicy value) => setState(() => _policy = value);

  String? get _dogError {
    if (_value.dogMode == PetDogMode.sizes && _value.dogSizes.isEmpty) {
      return 'Escolha pelo menos um porte.';
    }
    if (_value.dogMode == PetDogMode.list && _value.dogBreeds.isEmpty) {
      return 'Escolha pelo menos uma raça.';
    }
    return null;
  }

  String? get _catError =>
      _value.catMode == PetCatMode.list && _value.catBreeds.isEmpty
      ? 'Escolha pelo menos uma raça.'
      : null;

  List<TeamCompany> _otherCompanies(BuildContext context) {
    final controller = AppScope.of(context);
    return controller.companies
        .where(
          (company) =>
              company.id != controller.company?.id &&
              company.user.isManager &&
              company.user.canManage('SETTINGS'),
        )
        .toList();
  }

  Future<List<String>?> _pick(
    String species,
    String title,
    List<String> codes,
  ) => Navigator.push<List<String>>(
    context,
    MaterialPageRoute(
      builder: (_) =>
          BreedListScreen(species: species, title: title, selected: codes),
    ),
  );

  Future<void> _save() async {
    setState(() => _tried = true);
    if (_dogError != null || _catError != null) return;
    final controller = AppScope.of(context);
    final others = _otherCompanies(
      context,
    ).where((company) => _alsoIn.contains(company.id)).toList();
    final failed = await controller.savePetPolicy(_value, alsoIn: others);
    if (failed == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          failed.isEmpty
              ? 'Pets atendidos salvos.'
              : 'Pets atendidos salvos aqui. Não deu para aplicar em: '
                    '${failed.join(', ')}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final value = _value;
    final others = _otherCompanies(context);
    final dogError = _tried ? _dogError : null;
    final catError = _tried ? _catError : null;
    return AppScreenTips(
      screen: TipScreens.petPolicy,
      tips: TeamTips.petPolicy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Pets atendidos')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          children: [
            const Text(
              'Escolha os pets que o petshop atende. Um pet fora da regra '
              'continua no cadastro do cliente, aparece com aviso e não pode '
              'ser agendado, nem pelo app nem pela equipe. Agendamentos já '
              'marcados continuam valendo.',
            ),
            if (controller.error != null) ...[
              const SizedBox(height: 12),
              Text(
                controller.error!,
                style: const TextStyle(color: AppColors.danger),
              ),
            ],
            const SectionTitle('Cachorros'),
            AppTourTarget(
              id: TipTargets.petPolicyDogs,
              child: _Option(
                label: 'Todos os cachorros',
                selected: value.dogMode == PetDogMode.all,
                onTap: () => _set(value.copyWith(dogMode: PetDogMode.all)),
              ),
            ),
            _Option(
              label: 'Por porte',
              detail: 'O porte vem da raça, pelo peso de adulto.',
              selected: value.dogMode == PetDogMode.sizes,
              onTap: () => _set(value.copyWith(dogMode: PetDogMode.sizes)),
            ),
            if (value.dogMode == PetDogMode.sizes)
              Padding(
                padding: const EdgeInsets.only(left: 36, bottom: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (size, weight) in const [
                      ('Pequeno', 'até 10 kg'),
                      ('Médio', '10 a 25 kg'),
                      ('Grande', 'mais de 25 kg'),
                    ])
                      FilterChip(
                        label: Text('$size · $weight'),
                        selected: value.dogSizes.contains(size),
                        onSelected: (on) => _set(
                          value.copyWith(
                            dogSizes: [
                              for (final item in PetBreeds.sizes)
                                if (item == size
                                    ? on
                                    : value.dogSizes.contains(item))
                                  item,
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            _Option(
              label: 'Só as raças da minha lista',
              selected: value.dogMode == PetDogMode.list,
              onTap: () => _set(value.copyWith(dogMode: PetDogMode.list)),
            ),
            if (value.dogMode == PetDogMode.list)
              _ListButton(
                label: 'Raças atendidas',
                count: value.dogBreeds.length,
                onTap: () async {
                  final codes = await _pick(
                    'Cachorro',
                    'Cachorros atendidos',
                    value.dogBreeds,
                  );
                  if (codes != null) _set(_value.copyWith(dogBreeds: codes));
                },
              ),
            _Option(
              label: 'Não atendemos cachorros',
              selected: value.dogMode == PetDogMode.none,
              onTap: () => _set(value.copyWith(dogMode: PetDogMode.none)),
            ),
            if (value.dogMode == PetDogMode.all ||
                value.dogMode == PetDogMode.sizes)
              _ListButton(
                label: 'Raças que não atendemos',
                count: value.dogExcluded.length,
                onTap: () async {
                  final codes = await _pick(
                    'Cachorro',
                    'Cachorros que não atendemos',
                    value.dogExcluded,
                  );
                  if (codes != null) _set(_value.copyWith(dogExcluded: codes));
                },
              ),
            if (dogError != null) _Error(dogError),
            const SectionTitle('Gatos'),
            _Option(
              label: 'Todos os gatos',
              selected: value.catMode == PetCatMode.all,
              onTap: () => _set(value.copyWith(catMode: PetCatMode.all)),
            ),
            _Option(
              label: 'Só as raças da minha lista',
              selected: value.catMode == PetCatMode.list,
              onTap: () => _set(value.copyWith(catMode: PetCatMode.list)),
            ),
            if (value.catMode == PetCatMode.list)
              _ListButton(
                label: 'Raças atendidas',
                count: value.catBreeds.length,
                onTap: () async {
                  final codes = await _pick(
                    'Gato',
                    'Gatos atendidos',
                    value.catBreeds,
                  );
                  if (codes != null) _set(_value.copyWith(catBreeds: codes));
                },
              ),
            _Option(
              label: 'Não atendemos gatos',
              selected: value.catMode == PetCatMode.none,
              onTap: () => _set(value.copyWith(catMode: PetCatMode.none)),
            ),
            if (value.catMode == PetCatMode.all)
              _ListButton(
                label: 'Raças que não atendemos',
                count: value.catExcluded.length,
                onTap: () async {
                  final codes = await _pick(
                    'Gato',
                    'Gatos que não atendemos',
                    value.catExcluded,
                  );
                  if (codes != null) _set(_value.copyWith(catExcluded: codes));
                },
              ),
            if (catError != null) _Error(catError),
            const SectionTitle('Filhotes (menos de 12 meses)'),
            AppTourTarget(
              id: TipTargets.petPolicyPuppies,
              child: _Option(
                label: 'Seguem a regra acima',
                selected: value.puppies == PetPuppyRule.rule,
                onTap: () => _set(value.copyWith(puppies: PetPuppyRule.rule)),
              ),
            ),
            _Option(
              label: 'Atendemos todos os filhotes',
              detail: 'Mesmo de raça ou porte fora da regra.',
              selected: value.puppies == PetPuppyRule.all,
              onTap: () => _set(value.copyWith(puppies: PetPuppyRule.all)),
            ),
            _Option(
              label: 'Não atendemos filhotes',
              selected: value.puppies == PetPuppyRule.none,
              onTap: () => _set(value.copyWith(puppies: PetPuppyRule.none)),
            ),
            if (others.isNotEmpty) ...[
              const SectionTitle('Aplicar também a'),
              for (final company in others)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _alsoIn.contains(company.id),
                  title: Text(company.name),
                  onChanged: (on) => setState(
                    () => on == true
                        ? _alsoIn.add(company.id)
                        : _alsoIn.remove(company.id),
                  ),
                ),
            ],
            const SizedBox(height: 24),
            AppTourTarget(
              id: TipTargets.petPolicySave,
              child: FilledButton(
                onPressed: controller.busy ? null : _save,
                child: const Text('Salvar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.label,
    required this.selected,
    required this.onTap,
    this.detail,
  });
  final String label;
  final String? detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    inMutuallyExclusiveGroup: true,
    checked: selected,
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Icon(
        selected
            ? Icons.radio_button_checked_rounded
            : Icons.radio_button_unchecked_rounded,
        color: selected ? AppColors.primary : AppColors.muted,
      ),
      title: Text(label),
      subtitle: detail == null ? null : Text(detail!),
    ),
  );
}

class _ListButton extends StatelessWidget {
  const _ListButton({
    required this.label,
    required this.count,
    required this.onTap,
  });
  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 36, bottom: 8),
    child: AppContentCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        title: Text(label),
        subtitle: Text(
          count == 0
              ? 'Nenhuma raça escolhida'
              : count == 1
              ? '1 raça'
              : '$count raças',
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    ),
  );
}

class _Error extends StatelessWidget {
  const _Error(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 36, top: 4),
    child: Text(text, style: const TextStyle(color: AppColors.danger)),
  );
}

/// Breeds of a species to mark, grouped by size; the search tolerates
/// accents and typos. Returns the codes marked, in the order of the list.
class BreedListScreen extends StatefulWidget {
  const BreedListScreen({
    super.key,
    required this.species,
    required this.title,
    required this.selected,
  });
  final String species;
  final String title;
  final List<String> selected;

  @override
  State<BreedListScreen> createState() => _BreedListScreenState();
}

class _BreedListScreenState extends State<BreedListScreen> {
  late final Set<String> _selected = {...widget.selected};
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<PetBreed> get _all => PetBreeds.ofSpecies(widget.species);

  void _toggle(PetBreed breed) => setState(
    () => _selected.contains(breed.code)
        ? _selected.remove(breed.code)
        : _selected.add(breed.code),
  );

  Widget _tile(PetBreed breed) => CheckboxListTile(
    value: _selected.contains(breed.code),
    onChanged: (_) => _toggle(breed),
    secondary: AppPetIcon(icon: breed.icon, size: 40),
    title: Text(breed.name),
    subtitle: widget.species == 'Gato' ? null : Text('Porte ${breed.size}'),
  );

  @override
  Widget build(BuildContext context) {
    final typed = _query.text.trim();
    final groups = widget.species == 'Gato'
        ? [('', _all)]
        : [
            for (final size in PetBreeds.sizes)
              (size, _all.where((breed) => breed.size == size).toList()),
          ];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, [
              for (final breed in _all)
                if (_selected.contains(breed.code)) breed.code,
            ]),
            child: const Text('Pronto'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _query,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Buscar raça',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _selected.isEmpty
                      ? 'Nenhuma raça marcada'
                      : '${_selected.length} marcada${_selected.length == 1 ? '' : 's'}',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: typed.isNotEmpty
                    ? [
                        for (final match in searchPetBreeds(typed, _all))
                          _tile(match.breed),
                      ]
                    : [
                        for (final (size, breeds) in groups) ...[
                          if (size.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Porte $size',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => setState(() {
                                      final all = breeds.every(
                                        (breed) =>
                                            _selected.contains(breed.code),
                                      );
                                      for (final breed in breeds) {
                                        all
                                            ? _selected.remove(breed.code)
                                            : _selected.add(breed.code);
                                      }
                                    }),
                                    child: Text(
                                      breeds.every(
                                            (breed) =>
                                                _selected.contains(breed.code),
                                          )
                                          ? 'Desmarcar todas'
                                          : 'Marcar todas',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          for (final breed in breeds) _tile(breed),
                        ],
                      ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
