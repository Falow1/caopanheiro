import 'package:caopanheiro_core/caopanheiro_core.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppTextStyles;
import 'package:flutter/material.dart';

import '../../core/widgets.dart';
import '../../state/app_controller.dart';
import '../../state/app_scope.dart';

/// Each person of the team edits their own name and phone. The e-mail is the
/// login and does not change here.
class OwnProfileFormScreen extends StatefulWidget {
  const OwnProfileFormScreen({super.key});
  @override
  State<OwnProfileFormScreen> createState() => _OwnProfileFormScreenState();
}

class _OwnProfileFormScreenState extends State<OwnProfileFormScreen> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _name, _phone;

  // Read without listening: initState and the save run outside build.
  AppController get _controller =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;

  @override
  void initState() {
    super.initState();
    final user = _controller.user;
    _name = TextEditingController(text: user?.name ?? '');
    _phone = TextEditingController(text: displayPhone(user?.phone ?? ''));
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  String? _nameRule(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Preencha este campo';
    if (name.length < 2) return 'Informe o nome completo';
    return null;
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    final saved = await _controller.updateOwnProfile(
      _name.text.trim(),
      formatBrazilPhone(_phone.text) ?? _phone.text.trim(),
    );
    if (!saved || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Seus dados foram salvos.')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return FormScaffold(
      title: 'Meus dados',
      child: Form(
        key: _key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _name,
              validator: _nameRule,
              textCapitalization: TextCapitalization.words,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _phone,
              validator: phoneValidator,
              keyboardType: TextInputType.phone,
              inputFormatters: const [PhoneInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Telefone',
                hintText: phoneHint,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'O nome e o telefone mudam em todos os petshops em que você trabalha. O e-mail de entrada continua o mesmo.',
              style: AppTextStyles.captionMuted,
            ),
            const SizedBox(height: 24),
            if (controller.error != null) ...[
              Text(controller.error!),
              const SizedBox(height: 12),
            ],
            FilledButton(
              onPressed: controller.busy ? null : _save,
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
}

/// Opens [OwnProfileFormScreen] from a profile.
class EditOwnProfileButton extends StatelessWidget {
  const EditOwnProfileButton({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    if (!controller.ownProfileEditable) return const SizedBox.shrink();
    return OutlinedButton.icon(
      key: const ValueKey('edit-own-profile'),
      onPressed: controller.busy
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const OwnProfileFormScreen()),
            ),
      icon: const Icon(Icons.edit_outlined),
      label: const Text('Editar meus dados'),
    );
  }
}
