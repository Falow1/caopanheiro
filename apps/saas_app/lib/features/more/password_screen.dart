import 'package:flutter/material.dart';
import '../../core/widgets.dart';
import '../../state/app_scope.dart';
import '../auth/login_screen.dart';

class PasswordScreen extends StatefulWidget {
  const PasswordScreen({super.key});
  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController(),
      _password = TextEditingController(),
      _confirmation = TextEditingController();
  @override
  void dispose() {
    _current.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return FormPage(
      title: 'Alterar senha',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Após a alteração será necessário entrar novamente. As outras sessões desta conta serão encerradas.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _current,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Senha atual'),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Informe a senha atual' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nova senha'),
              validator: (v) => v == null || v.length < 8 || v.length > 128
                  ? 'Use de 8 a 128 caracteres'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmation,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirmar nova senha',
              ),
              validator: (v) =>
                  v != _password.text ? 'As senhas precisam ser iguais' : null,
            ),
            if (controller.error != null) Text(controller.error!),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: controller.busy || controller.readOnly
                  ? null
                  : () async {
                      if (!_form.currentState!.validate()) return;
                      final success = await controller.changePassword(
                        _current.text,
                        _password.text,
                      );
                      if (!context.mounted) return;
                      if (success || controller.admin == null) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                          (_) => false,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'Senha alterada. Entre novamente.'
                                  : 'Operação sem confirmação. Confira o acesso antes de repetir.',
                            ),
                          ),
                        );
                      }
                    },
              child: const Text('Salvar nova senha'),
            ),
          ],
        ),
      ),
    );
  }
}
