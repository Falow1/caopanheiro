import 'package:caopanheiro_contracts/caopanheiro_contracts.dart'
    show PetBreed, petServiceText;
import 'package:caopanheiro_core/caopanheiro_core.dart';
import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppPetIcon, AppRadii;

import '../../core/utils/formatters.dart';
import '../../core/widgets/confirm_dialogs.dart';
import '../../domain/models/pet.dart';
import '../../state/app_controller.dart';
import '../../state/app_scope.dart';
import '../navigation/tutor_wide_layout.dart';
import 'breed_field.dart';

/// Birth date as the server keeps it (yyyy-MM-dd).
String _day(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

class PetFormScreen extends StatefulWidget {
  const PetFormScreen({super.key, this.pet});
  final Pet? pet;
  @override
  State<PetFormScreen> createState() => _PetFormScreenState();
}

class _PetFormScreenState extends State<PetFormScreen> {
  final _newId = newRecordId();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.pet?.name,
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.pet?.notes,
  );
  late String _species = widget.pet?.species ?? 'Cachorro';
  // No size to choose: it comes from the breed, on the server too.
  late PetBreed? _breed = widget.pet?.breedEntry;
  String? _suggestion;
  bool _breedMissing = false;
  late DateTime _birthDate = widget.pet?.birthDate ?? DateTime(2023, 1, 1);
  (String, String?, DateTime, String, String) get _values =>
      (_species, _breed?.code, _birthDate, _name.text, _notes.text);
  late final (String, String?, DateTime, String, String) _initial;
  bool get _dirty => _values != _initial;

  @override
  void initState() {
    super.initState();
    _initial = _values;
    for (final field in [_name, _notes]) {
      field.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _birthDate,
      firstDate: DateTime(1995),
      lastDate: DateTime.now(),
    );
    if (date != null) setState(() => _birthDate = date);
  }

  /// A new pet or a new breed follows the rule of the petshop; the other
  /// data of a pet it no longer serves can still be edited.
  String? get _breedError {
    final breed = _breed;
    if (breed == null) return _breedMissing ? 'Escolha a raça' : null;
    final pet = widget.pet;
    if (pet != null && pet.breedEntry?.code == breed.code) return null;
    final controller = AppScope.of(context);
    final reason = controller.petPolicy.evaluate(
      breed,
      birthDate: _day(_birthDate),
    );
    return reason == null
        ? null
        : petServiceText(
            reason,
            petName: 'o pet',
            breed: breed,
            petshop: controller.companyName,
          );
  }

  Future<void> _save() async {
    final valid = _formKey.currentState!.validate();
    setState(() => _breedMissing = _breed == null);
    final breed = _breed;
    if (!valid || breed == null || _breedError != null) return;
    final pet = Pet.withBreed(
      id: widget.pet?.id ?? _newId,
      recordNumber: widget.pet?.recordNumber,
      name: _name.text.trim(),
      breed: breed,
      birthDate: _birthDate,
      notes: _notes.text.trim(),
      breedSuggestion: _suggestion,
    );
    if (await AppScope.of(context).savePet(pet) && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${pet.name} foi salvo.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    String? required(String? value) =>
        value == null || value.trim().isEmpty ? 'Preencha este campo' : null;
    return DiscardGuard(dirty: _dirty, child: _form(controller, required));
  }

  Widget _form(AppController controller, String? Function(String?) required) {
    // With a keyboard, Enter on a line field saves, as on the web. The phone
    // keeps Próximo on its keyboard; Observações takes several lines.
    final enter = tutorWide(context);
    final action = enter ? TextInputAction.done : TextInputAction.next;
    void submit(String _) {
      if (!controller.busy) _save();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pet == null ? 'Adicionar pet' : 'Editar pet'),
      ),
      body: Form(
        key: _formKey,
        // The column of 620 on wide windows, Salvar fixed at the bottom on
        // the phone; the same list on both, so the typed text and the scroll
        // survive a resize.
        child: TutorFormPage(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          save: FilledButton(
            onPressed: controller.busy ? null : _save,
            child: Text(controller.busy ? 'Salvando...' : 'Salvar'),
          ),
          cancel: TextButton(
            onPressed: () => Navigator.maybePop(context),
            child: const Text('Cancelar'),
          ),
          children: [
            if (controller.error != null) Text(controller.error!),
            Align(child: AppPetIcon(icon: _breed?.icon, size: 96)),
            const SizedBox(height: 24),
            TextFormField(
              controller: _name,
              validator: required,
              textInputAction: action,
              onFieldSubmitted: enter ? submit : null,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _species,
              decoration: const InputDecoration(labelText: 'Espécie'),
              items: const [
                DropdownMenuItem(value: 'Cachorro', child: Text('Cachorro')),
                DropdownMenuItem(value: 'Gato', child: Text('Gato')),
              ],
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
              policy: controller.petPolicy,
              birthDate: _day(_birthDate),
              texts: BreedTexts.tutor,
              petshop: controller.companyName,
              legacyBreed:
                  _breed != null &&
                      _breed!.code == widget.pet?.breedEntry?.code &&
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
            InkWell(
              onTap: _pickDate,
              borderRadius: AppRadii.r16,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Nascimento aproximado',
                  suffixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(
                  formatDate(_birthDate),
                  // As typed in the other fields: it looked disabled.
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Observações',
                hintText: 'Alergias, comportamento, preferências...',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
