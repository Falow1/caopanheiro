import 'package:flutter/material.dart';

import '../../core/widgets/confirm_dialogs.dart';
import '../../domain/models/tutor.dart';
import '../../domain/policies/contact_input.dart';
import '../../state/app_scope.dart';
import '../navigation/tutor_wide_layout.dart';

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

  bool get _dirty {
    final initial = _initial;
    return initial != null &&
        (_name!.text != initial.name ||
            _phone!.text != displayPhone(initial.phone) ||
            _email!.text != initial.email);
  }

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
    }
  }

  @override
  void dispose() {
    _name?.dispose();
    _phone?.dispose();
    _email?.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final controller = AppScope.of(context);
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
            ],
          ),
        ),
      ),
    );
  }
}
