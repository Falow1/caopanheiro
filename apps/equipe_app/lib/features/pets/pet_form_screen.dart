import 'package:caopanheiro_contracts/caopanheiro_contracts.dart'
    show PetBreed, petServiceText;
import 'package:caopanheiro_core/caopanheiro_core.dart';
import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppColors, AppPetIcon, AppRadii;

import '../../core/widgets.dart';
import '../../data/team_json.dart' show petBirthDate;
import '../../domain/models.dart';
import '../../state/app_scope.dart';
import 'breed_field.dart';

class PetFormScreen extends StatefulWidget {
  const PetFormScreen({super.key, required this.customerId, this.pet});
  final String customerId;
  final Pet? pet;
  @override
  State<PetFormScreen> createState() => _PetFormScreenState();
}

class _PetFormScreenState extends State<PetFormScreen> {
  late final _petId = widget.pet?.id ?? newRecordId();
  final _key = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.pet?.name);
  late final _notes = TextEditingController(text: widget.pet?.notes);
  late String _species = widget.pet?.species ?? 'Cachorro';
  // The size is not chosen: it comes from the breed, on the server too.
  late PetBreed? _breed = widget.pet?.breedEntry;
  String? _suggestion;
  bool _breedMissing = false;
  late DateTime _birth = widget.pet?.birthDate ?? DateTime(2023, 1, 1);

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  /// A new pet or a new breed follows the rule of the petshop; the other
  /// data of a pet it no longer serves can still be edited.
  String? get _breedError {
    final breed = _breed;
    if (breed == null) return _breedMissing ? 'Escolha a raça' : null;
    if (widget.pet != null && widget.pet!.breedEntry?.code == breed.code) {
      return null;
    }
    final reason = AppScope.of(
      context,
    ).petPolicy.evaluate(breed, birthDate: petBirthDate(_birth));
    return reason == null
        ? null
        : petServiceText(reason, petName: 'o pet', breed: breed);
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Preencha este campo' : null;

  Future<void> _save() async {
    final valid = _key.currentState!.validate();
    setState(() => _breedMissing = _breed == null);
    if (!valid || _breed == null || _breedError != null) return;
    final value = Pet.withBreed(
      id: _petId,
      recordNumber: widget.pet?.recordNumber,
      name: _name.text.trim(),
      breed: _breed!,
      birthDate: _birth,
      notes: _notes.text.trim(),
      breedSuggestion: _suggestion,
    );
    if (await AppScope.of(context).savePet(widget.customerId, value) &&
        mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => FormScaffold(
    title: widget.pet == null ? 'Adicionar pet' : 'Editar pet',
    child: AppScope.of(context).catalogOffline
        ? const PermissionNotice(
            message:
                'Conecte-se e atualize os dados para cadastrar ou editar pets.',
          )
        : Form(
            key: _key,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(child: AppPetIcon(icon: _breed?.icon, size: 96)),
                if (AppScope.of(context).error != null)
                  Text(AppScope.of(context).error!),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _name,
                  validator: _required,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _species,
                  decoration: const InputDecoration(labelText: 'Espécie'),
                  items: ['Cachorro', 'Gato']
                      .map(
                        (item) =>
                            DropdownMenuItem(value: item, child: Text(item)),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    if (value == _species) return;
                    _species = value!;
                    _breed = null;
                    _suggestion = null;
                  }),
                ),
                const SizedBox(height: 14),
                BreedField(
                  species: _species,
                  value: _breed,
                  policy: AppScope.of(context).petPolicy,
                  birthDate: petBirthDate(_birth),
                  legacyBreed:
                      _breed != null &&
                          _breed!.code == widget.pet?.breedCode &&
                          widget.pet?.breedPending == true
                      ? widget.pet?.legacyBreed
                      : null,
                  error: _breedError,
                  onChanged: (choice) => setState(() {
                    _breed = choice.breed;
                    _suggestion = choice.suggestion;
                    _breedMissing = false;
                  }),
                ),
                const SizedBox(height: 14),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadii.r15,
                    side: const BorderSide(color: AppColors.line),
                  ),
                  tileColor: Colors.white,
                  title: const Text('Nascimento aproximado'),
                  subtitle: Text(
                    '${_birth.day.toString().padLeft(2, '0')}/${_birth.month.toString().padLeft(2, '0')}/${_birth.year}',
                  ),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: () async {
                    final value = await showDatePicker(
                      context: context,
                      initialDate: _birth,
                      firstDate: DateTime(1995),
                      lastDate: DateTime.now(),
                    );
                    if (value != null) setState(() => _birth = value);
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _notes,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Observações'),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: AppScope.of(context).busy ? null : _save,
                  child: const Text('Salvar'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ),
  );
}
