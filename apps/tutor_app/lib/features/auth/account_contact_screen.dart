import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppContentCard;

import '../../core/theme/app_theme.dart';
import '../../core/widgets/confirm_dialogs.dart';
import '../../domain/policies/contact_input.dart';
import '../../state/app_scope.dart';
import 'auth_welcome_layout.dart';
import 'login_screen.dart';

/// Shown once after entering when the account has no phone, as an account
/// created by Google: the sign-up by e-mail already asks for it. With the
/// name and phone in the account, a petshop's link only links.
class AccountContactScreen extends StatefulWidget {
  const AccountContactScreen({super.key});
  @override
  State<AccountContactScreen> createState() => _AccountContactScreenState();
}

class _AccountContactScreenState extends State<AccountContactScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _filled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // What the account already has (the Google name) comes filled.
    if (_filled) return;
    _filled = true;
    final tutor = AppScope.of(context).tutor;
    _name.text = tutor?.name ?? '';
    _phone.text = displayPhone(tutor?.phone ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    await AppScope.of(context).saveAccountContact(
      normalizePersonName(_name.text),
      formatBrazilPhone(_phone.text)!,
    );
  }

  Future<void> _confirmSignOut() async {
    if (!await confirmSignOut(context) || !mounted) return;
    AppScope.of(context).signOut(forgetInvite: true);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return AuthWelcomeLayout(
      title: 'Bom ter você\npor aqui.',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Seu cadastro'),
          actions: [
            IconButton(
              tooltip: 'Sair',
              onPressed: controller.busy ? null : _confirmSignOut,
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Complete seu cadastro',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Confira seu nome e informe seu telefone. O petshop usa esses dados no seu cadastro de cliente, e você só faz isso uma vez.',
                ),
                const SizedBox(height: 16),
                AppContentCard(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _name,
                          enabled: !controller.busy,
                          validator: personNameValidator,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Nome completo',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phone,
                          enabled: !controller.busy,
                          validator: phoneValidator,
                          keyboardType: TextInputType.phone,
                          inputFormatters: const [PhoneInputFormatter()],
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) =>
                              controller.busy ? null : _save(),
                          decoration: const InputDecoration(
                            labelText: 'Telefone',
                            hintText: phoneHint,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: controller.busy ? null : _save,
                          child: const Text('Salvar e continuar'),
                        ),
                      ],
                    ),
                  ),
                ),
                if (controller.error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    controller.error!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
