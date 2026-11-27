// Breed of the pet form: search on the list, with help when the breed is not
// found. The same file lives in the Tutor app (features/pets/breed_field.dart);
// keep both equal, apart from the [BreedTexts] each one passes.
import 'package:caopanheiro_contracts/caopanheiro_contracts.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppColors, AppPetIcon, AppRadii, AppScreenTips, AppTourTarget;
import 'package:flutter/material.dart';

import '../../core/screen_tips.dart';

/// Breed chosen and, for "Outra raça", the name typed for the platform to
/// evaluate ("Raças sugeridas").
class BreedChoice {
  const BreedChoice(this.breed, {this.suggestion});
  final PetBreed breed;
  final String? suggestion;
}

/// Words that change between the tutor (own pet) and the team.
class BreedTexts {
  const BreedTexts({
    required this.notFound,
    required this.hasBreed,
    required this.weight,
  });
  static const team = BreedTexts(
    notFound: 'Não achei a raça do pet',
    hasBreed: 'O pet tem raça?',
    weight: 'Quanto ele pesa adulto, ou quanto deve pesar?',
  );
  static const tutor = BreedTexts(
    notFound: 'Não achei a raça do meu pet',
    hasBreed: 'Seu pet tem raça?',
    weight: 'Quanto ele pesa adulto, ou quanto deve pesar?',
  );
  final String notFound;
  final String hasBreed;
  final String weight;
}

String breedSizeText(PetBreed breed) =>
    breed.species == 'Gato' ? 'Gato' : 'Porte: ${breed.size} (pela raça)';

/// Field of the form: shows the breed with its icon and size; a tap opens the
/// search. [error] is shown under it (for example, a breed not served).
class BreedField extends StatelessWidget {
  const BreedField({
    super.key,
    required this.species,
    required this.value,
    required this.policy,
    required this.birthDate,
    required this.onChanged,
    this.texts = BreedTexts.team,
    this.legacyBreed,
    this.error,
    this.petshop = 'Este petshop',
  });

  final String species;
  final PetBreed? value;
  final PetPolicy policy;
  final String? birthDate;
  final ValueChanged<BreedChoice> onChanged;
  final BreedTexts texts;

  /// Text of a pet saved before the list, not found on it.
  final String? legacyBreed;
  final String? error;
  final String petshop;

  Future<void> _open(BuildContext context) async {
    final choice = await Navigator.of(context).push<BreedChoice>(
      MaterialPageRoute(
        builder: (_) => BreedPickerScreen(
          species: species,
          policy: policy,
          birthDate: birthDate,
          texts: texts,
          petshop: petshop,
        ),
      ),
    );
    if (choice != null) onChanged(choice);
  }

  @override
  Widget build(BuildContext context) {
    final breed = value;
    final legacy = legacyBreed;
    return Semantics(
      button: true,
      label: 'Raça',
      child: InkWell(
        borderRadius: AppRadii.r15,
        onTap: () => _open(context),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Raça',
            errorText: error,
            errorMaxLines: 3,
            helperText: legacy != null && legacy.isNotEmpty
                ? 'Antes: "$legacy". Escolha a raça na lista.'
                : null,
            helperMaxLines: 2,
            suffixIcon: const Icon(Icons.search),
          ),
          child: Row(
            children: [
              AppPetIcon(icon: breed?.icon, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: breed == null
                    ? const Text(
                        'Escolha a raça',
                        style: TextStyle(color: AppColors.muted),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            breed.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            breedSizeText(breed),
                            style: const TextStyle(color: AppColors.muted),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Search of the breed list. Only breeds the petshop serves can be chosen;
/// a breed it does not serve shows up disabled with the reason.
class BreedPickerScreen extends StatefulWidget {
  const BreedPickerScreen({
    super.key,
    required this.species,
    required this.policy,
    required this.birthDate,
    this.texts = BreedTexts.team,
    this.petshop = 'Este petshop',
  });

  final String species;
  final PetPolicy policy;
  final String? birthDate;
  final BreedTexts texts;
  final String petshop;

  @override
  State<BreedPickerScreen> createState() => _BreedPickerScreenState();
}

class _BreedPickerScreenState extends State<BreedPickerScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  PetServiceReason? _reason(PetBreed breed) =>
      widget.policy.evaluate(breed, birthDate: widget.birthDate);

  Future<T?> _ask<T>(String title, List<(T, String)> options) => showDialog<T>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(title),
      children: [
        for (final (value, label) in options)
          SimpleDialogOption(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            onPressed: () => Navigator.pop(context, value),
            child: Text(label),
          ),
      ],
    ),
  );

  Future<String?> _suggestion() async {
    final value = await showDialog<String>(
      context: context,
      builder: (context) => PetTextDialog(
        title: 'Qual é a raça?',
        message:
            'Opcional. O nome vai para a equipe do Cãopanheiro avaliar se '
            'inclui a raça na lista; ele não fica no cadastro do pet.',
        label: 'Nome da raça',
        initial: _query.text.trim(),
        maxLength: 60,
        confirmLabel: 'Enviar',
        cancelLabel: 'Pular',
      ),
    );
    return value == null || value.length < 2 ? null : value;
  }

  /// "Não achei a raça": has a breed → "Outra raça"; no or does not know →
  /// sem raça definida; for dogs, the adult weight gives the size.
  Future<void> _help() async {
    final hasBreed = await _ask<bool>(widget.texts.hasBreed, const [
      (true, 'Sim, mas não está na lista'),
      (false, 'Não, é vira-lata (SRD)'),
      (false, 'Não sei'),
    ]);
    if (hasBreed == null || !mounted) return;
    String? size;
    if (widget.species != 'Gato') {
      size = await _ask<String>(widget.texts.weight, const [
        ('Pequeno', 'Até 10 kg'),
        ('Médio', 'De 10 a 25 kg'),
        ('Grande', 'Mais de 25 kg'),
      ]);
      if (size == null || !mounted) return;
    }
    final breed = hasBreed
        ? PetBreeds.other(widget.species, size)
        : PetBreeds.srd(widget.species, size);
    final suggestion = hasBreed ? await _suggestion() : null;
    if (!mounted) return;
    Navigator.pop(context, BreedChoice(breed, suggestion: suggestion));
  }

  @override
  Widget build(BuildContext context) {
    final typed = _query.text.trim();
    final all = PetBreeds.ofSpecies(widget.species);
    final matches = searchPetBreeds(
      typed,
      typed.isEmpty ? all.where((breed) => _reason(breed) == null) : all,
      limit: typed.isEmpty ? all.length : 40,
    );
    final served = [
      for (final match in matches)
        if (_reason(match.breed) == null) match,
    ];
    final refused = [
      for (final match in matches)
        if (_reason(match.breed) != null) match,
    ];
    final guessed = matches.isNotEmpty && matches.first.approximate;
    return AppScreenTips(
      screen: TipScreens.breed,
      tips: breedPickerTips,
      child: _scaffold(typed, matches, served, refused, guessed),
    );
  }

  Widget _scaffold(
    String typed,
    List<PetBreedMatch> matches,
    List<PetBreedMatch> served,
    List<PetBreedMatch> refused,
    bool guessed,
  ) {
    return Scaffold(
      appBar: AppBar(title: const Text('Raça')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: AppTourTarget(
                id: TipTargets.breedSearch,
                child: TextField(
                  controller: _query,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Buscar raça',
                    hintText: widget.species == 'Gato'
                        ? 'Ex.: siamês, persa, vira-lata'
                        : 'Ex.: shih tzu, labrador, vira-lata',
                    prefixIcon: const Icon(Icons.search),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  if (typed.isNotEmpty && matches.isEmpty)
                    _Note('Não encontramos "$typed" na lista.'),
                  if (guessed) const _Note('Você quis dizer…?'),
                  if (typed.isEmpty) const _Note('Raças que o petshop atende.'),
                  for (final match in served)
                    _BreedTile(
                      breed: match.breed,
                      onTap: () =>
                          Navigator.pop(context, BreedChoice(match.breed)),
                    ),
                  for (final match in refused)
                    _BreedTile(
                      breed: match.breed,
                      refusal: petServiceText(
                        _reason(match.breed)!,
                        petName: 'o pet',
                        breed: match.breed,
                        petshop: widget.petshop,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: AppTourTarget(
                      id: TipTargets.breedHelp,
                      child: OutlinedButton.icon(
                        onPressed: _help,
                        icon: const Icon(Icons.help_outline),
                        label: Text(widget.texts.notFound),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog with one text field. It owns the controller, so the field is not
/// disposed while the dialog is still closing. Returns the trimmed text, or
/// null when cancelled.
class PetTextDialog extends StatefulWidget {
  const PetTextDialog({
    super.key,
    required this.title,
    required this.message,
    required this.label,
    required this.maxLength,
    required this.confirmLabel,
    this.cancelLabel = 'Cancelar',
    this.initial = '',
    this.minLength = 0,
    this.maxLines = 1,
  });

  final String title;
  final String message;
  final String label;
  final int maxLength;
  final String confirmLabel;
  final String cancelLabel;
  final String initial;

  /// Shorter text keeps the dialog open.
  final int minLength;
  final int maxLines;

  @override
  State<PetTextDialog> createState() => _PetTextDialogState();
}

class _PetTextDialogState extends State<PetTextDialog> {
  late final _field = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.message),
        const SizedBox(height: 12),
        TextField(
          controller: _field,
          autofocus: true,
          maxLength: widget.maxLength,
          maxLines: widget.maxLines,
          decoration: InputDecoration(labelText: widget.label),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(widget.cancelLabel),
      ),
      FilledButton(
        onPressed: () {
          final value = _field.text.trim();
          if (value.length >= widget.minLength) Navigator.pop(context, value);
        },
        child: Text(widget.confirmLabel),
      ),
    ],
  );
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    child: Text(
      text,
      style: const TextStyle(
        color: AppColors.muted,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _BreedTile extends StatelessWidget {
  const _BreedTile({required this.breed, this.onTap, this.refusal});
  final PetBreed breed;
  final VoidCallback? onTap;
  final String? refusal;

  @override
  Widget build(BuildContext context) => ListTile(
    enabled: onTap != null,
    onTap: onTap,
    leading: Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: AppPetIcon(icon: breed.icon, size: 44),
    ),
    title: Text(breed.name),
    subtitle: Text(refusal ?? breedSizeText(breed)),
  );
}
