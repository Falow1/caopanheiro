import 'package:caopanheiro_contracts/caopanheiro_contracts.dart'
    show petEmojiForSpecies;
import 'package:caopanheiro_core/caopanheiro_core.dart';
import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppRadii;

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/confirm_dialogs.dart';
import '../../domain/models/pet.dart';
import '../../state/app_controller.dart';
import '../../state/app_scope.dart';
import '../navigation/tutor_wide_layout.dart';

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
  late final TextEditingController _breed = TextEditingController(
    text: widget.pet?.breed,
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.pet?.notes,
  );
  late String _species = widget.pet?.species ?? 'Cachorro';
  late String _size = widget.pet?.size ?? 'Médio';
  late DateTime _birthDate = widget.pet?.birthDate ?? DateTime(2023, 1, 1);
  (String, String, DateTime, String, String, String) get _values =>
      (_species, _size, _birthDate, _name.text, _breed.text, _notes.text);
  late final (String, String, DateTime, String, String, String) _initial;
  bool get _dirty => _values != _initial;

  @override
  void initState() {
    super.initState();
    _initial = _values;
    for (final field in [_name, _breed, _notes]) {
      field.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _breed.dispose();
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final pet = Pet(
      id: widget.pet?.id ?? _newId,
      name: _name.text.trim(),
      species: _species,
      breed: _breed.text.trim(),
      size: _size,
      birthDate: _birthDate,
      notes: _notes.text.trim(),
      emoji: petEmojiForSpecies(_species),
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
            Align(
              child: Container(
                width: 90,
                height: 90,
                decoration: const BoxDecoration(
                  color: AppColors.mint,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    petEmojiForSpecies(_species),
                    style: const TextStyle(fontSize: 44),
                  ),
                ),
              ),
            ),
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
              onChanged: (value) => setState(() => _species = value!),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _breed,
              validator: required,
              textInputAction: action,
              onFieldSubmitted: enter ? submit : null,
              decoration: const InputDecoration(labelText: 'Raça'),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _size,
              decoration: const InputDecoration(labelText: 'Porte'),
              items: ['Pequeno', 'Médio', 'Grande']
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _size = value!),
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
