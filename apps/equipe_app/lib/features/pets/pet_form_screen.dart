import 'package:caopanheiro_contracts/caopanheiro_contracts.dart'
    show petEmojiForSpecies;
import 'package:caopanheiro_core/caopanheiro_core.dart';
import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppColors, AppRadii;

import '../../core/widgets.dart';
import '../../domain/models.dart';
import '../../state/app_scope.dart';

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
  late final _breed = TextEditingController(text: widget.pet?.breed);
  late final _notes = TextEditingController(text: widget.pet?.notes);
  late String _species = widget.pet?.species ?? 'Cachorro';
  late String _size = widget.pet?.size ?? 'Médio';
  late DateTime _birth = widget.pet?.birthDate ?? DateTime(2023, 1, 1);

  @override
  void dispose() {
    _name.dispose();
    _breed.dispose();
    _notes.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Preencha este campo' : null;

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    final value = Pet(
      id: _petId,
      name: _name.text.trim(),
      species: _species,
      breed: _breed.text.trim(),
      size: _size,
      birthDate: _birth,
      notes: _notes.text.trim(),
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
                Align(
                  child: Text(
                    petEmojiForSpecies(_species),
                    style: const TextStyle(fontSize: 65),
                  ),
                ),
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
                  onChanged: (value) => setState(() => _species = value!),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _breed,
                  validator: _required,
                  decoration: const InputDecoration(labelText: 'Raça'),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _size,
                  decoration: const InputDecoration(labelText: 'Porte'),
                  items: ['Pequeno', 'Médio', 'Grande']
                      .map(
                        (item) =>
                            DropdownMenuItem(value: item, child: Text(item)),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _size = value!),
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
