import 'package:flutter/material.dart';

import '../../core/widgets/confirm_dialogs.dart';
import '../../domain/models/tutor.dart';
import '../../domain/repositories/tutor_address_repository.dart';
import '../../domain/policies/contact_input.dart';
import '../../state/app_scope.dart';
import '../navigation/tutor_wide_layout.dart';
import '../transport/address_editor.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});
  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController? _name;
  TextEditingController? _phone;
  TextEditingController? _email;
  Tutor? _initial;

  // The address of the account for the transport, optional; null where the
  // repository does not keep one (demo data).
  AddressEditingController? _address;
  String? _addressError;

  bool get _tutorDirty {
    final initial = _initial;
    return initial != null &&
        (_name!.text != initial.name ||
            _phone!.text != displayPhone(initial.phone) ||
            _email!.text != initial.email);
  }

  /// The address to keep: null removes it; unchanged when it equals the saved.
  TutorAddress? get _addressTarget => _address!.empty ? null : _address!.value;
  bool get _addressDirty {
    final address = _address;
    if (address == null) return false;
    final saved = AppScope.of(context).savedAddress;
    return address.empty ? saved != null : address.value != saved;
  }

  bool get _dirty => _tutorDirty || _addressDirty;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_name == null) {
      final tutor = AppScope.of(context).tutor!;
      _initial = tutor;
      _name = TextEditingController(text: tutor.name);
      _phone = TextEditingController(text: displayPhone(tutor.phone));
      _email = TextEditingController(text: tutor.email);
      for (final field in [_name!, _phone!, _email!]) {
        field.addListener(() => setState(() {}));
      }
      final controller = AppScope.of(context);
      if (controller.addressAvailable) {
        _address = AddressEditingController(
          initial: controller.savedAddress,
          search: (query) => AppScope.of(context).searchTransportAddress(query),
          reverse: AppScope.of(context).addressAvailable
              ? (lat, lng) => AppScope.of(context).reverseAddress(lat, lng)
              : null,
        )..addListener(() => setState(() => _addressError = null));
      }
    }
  }

  @override
  void dispose() {
    _name?.dispose();
    _phone?.dispose();
    _email?.dispose();
    _address?.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final controller = AppScope.of(context);
    if (_address != null && !_address!.empty && _address!.value == null) {
      setState(
        () => _addressError =
            'Para guardar o endereço, preencha a rua com o número e o bairro e marque o ponto no mapa. Ou remova o endereço.',
      );
      return;
    }
    if (_addressDirty) {
      try {
        await controller.saveAddress(_addressTarget);
      } catch (error) {
        if (mounted) {
          setState(
            () => _addressError = error is FormatException
                ? error.message
                : 'Não foi possível salvar o endereço. Tente novamente com conexão.',
          );
        }
        return;
      }
      if (!mounted) return;
    }
    if (!_tutorDirty) {
      Navigator.pop(context);
      return;
    }
    if (await controller.saveTutor(
          Tutor(
            name: normalizePersonName(_name!.text),
            phone: formatBrazilPhone(_phone!.text)!,
            email: _email!.text.trim(),
          ),
        ) &&
        mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    if (controller.tutor == null) return const SizedBox.shrink();
    String? required(String? value) =>
        value == null || value.trim().isEmpty ? 'Preencha este campo' : null;
    // With a keyboard, Enter on a field saves, as on the web; the phone
    // keeps its keyboard as before.
    final ValueChanged<String>? submit = tutorWide(context)
        ? (_) {
            if (!controller.busy) _save();
          }
        : null;
    return DiscardGuard(
      dirty: _dirty,
      child: Scaffold(
        appBar: AppBar(title: const Text('Editar dados')),
        body: Form(
          key: _formKey,
          // The column of 620 on wide windows, Salvar fixed at the bottom
          // on the phone.
          child: TutorFormPage(
            padding: const EdgeInsets.all(20),
            save: FilledButton(
              onPressed: controller.busy ? null : _save,
              child: const Text('Salvar alterações'),
            ),
            cancel: TextButton(
              onPressed: () => Navigator.maybePop(context),
              child: const Text('Cancelar'),
            ),
            children: [
              if (controller.error != null) Text(controller.error!),
              TextFormField(
                controller: _name,
                validator: personNameValidator,
                onFieldSubmitted: submit,
                decoration: const InputDecoration(labelText: 'Nome'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phone,
                validator: phoneValidator,
                onFieldSubmitted: submit,
                keyboardType: TextInputType.phone,
                inputFormatters: const [PhoneInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Telefone',
                  hintText: phoneHint,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _email,
                validator: required,
                onFieldSubmitted: submit,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'E-mail'),
              ),
              if (_address case final address?) ...[
                const SizedBox(height: 28),
                Text(
                  'Endereço para o transporte',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Guardado na sua conta e usado na busca e na entrega dos pets. Opcional.',
                ),
                const SizedBox(height: 12),
                AddressFields(
                  controller: address,
                  enabled: !controller.busy,
                  required: false,
                ),
                AddressMap(controller: address, height: 300),
                if (_addressError case final error?)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (!address.empty)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      key: const ValueKey('profile-remove-address'),
                      onPressed: controller.busy ? null : address.clear,
                      icon: const Icon(Icons.location_off_outlined),
                      label: const Text('Remover endereço'),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
