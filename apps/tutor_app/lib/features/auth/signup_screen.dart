import 'package:flutter/material.dart';

import '../../domain/models/tutor.dart';
import '../../domain/policies/contact_input.dart';
import '../../domain/policies/tutor_invite.dart';
import '../../state/app_controller.dart';
import '../../state/app_scope.dart';
import '../navigation/main_shell.dart';
import '../navigation/tutor_wide_layout.dart';
import 'auth_welcome_layout.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final controller = AppScope.of(context);
    final success = await controller.signUp(
      Tutor(
        name: normalizePersonName(_name.text),
        phone: formatBrazilPhone(_phone.text)!,
        email: _email.text.trim(),
      ),
      _password.text,
    );
    if (success && mounted) {
      // Linking a petshop requires a confirmed e-mail; send it right away.
      // A failure here is recoverable from the access screen.
      await controller.sendVerification();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    String? required(String? value) =>
        value == null || value.trim().isEmpty ? 'Preencha este campo' : null;
    // On wide windows the greeting is on the green at the left.
    final wide = tutorWide(context);
    const title = 'Vamos começar';
    const message = 'Só precisamos do essencial para criar seu acesso.';
    return AuthWelcomeLayout(
      title: title,
      message: message,
      child: _page(controller, required, wide, title, message),
    );
  }

  Widget _page(
    AppController controller,
    String? Function(String?) required,
    bool wide,
    String title,
    String message,
  ) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!wide) ...[
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(message),
                    const SizedBox(height: 28),
                  ],
                  TextFormField(
                    controller: _name,
                    validator: personNameValidator,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nome completo',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _phone,
                    validator: phoneValidator,
                    keyboardType: TextInputType.phone,
                    inputFormatters: const [PhoneInputFormatter()],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Telefone',
                      hintText: phoneHint,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _email,
                    validator: (value) => looksLikeEmail(value ?? '')
                        ? null
                        : 'Informe um e-mail válido',
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      helperText:
                          'Você vai usar este e-mail para entrar no app.',
                      helperMaxLines: 2,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _password,
                    validator: (value) =>
                        (value?.length ?? 0) < minPasswordLength ||
                            (value?.length ?? 0) > maxPasswordLength
                        ? 'Use de $minPasswordLength a $maxPasswordLength caracteres'
                        : null,
                    obscureText: _obscure,
                    autofillHints: const [AutofillHints.newPassword],
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      helperText:
                          'Use de $minPasswordLength a $maxPasswordLength caracteres',
                      suffixIcon: IconButton(
                        tooltip: _obscure ? 'Mostrar senha' : 'Ocultar senha',
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _confirm,
                    validator: (value) => value != _password.text
                        ? 'As senhas não conferem'
                        : null,
                    obscureText: _obscure,
                    autofillHints: const [AutofillHints.newPassword],
                    onFieldSubmitted: (_) => controller.busy ? null : _submit(),
                    decoration: const InputDecoration(
                      labelText: 'Confirmar senha',
                    ),
                  ),
                  if (controller.error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      controller.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: controller.busy ? null : _submit,
                    child: Text(controller.busy ? 'Criando...' : 'Criar conta'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Voltar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
