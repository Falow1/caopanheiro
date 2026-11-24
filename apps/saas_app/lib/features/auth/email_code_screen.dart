import 'package:flutter/material.dart';
import 'package:caopanheiro_core/caopanheiro_core.dart'
    show FirebaseEnvironment, buildFirebaseEnvironment;
import '../../core/widgets.dart';
import '../../state/app_scope.dart';
import '../navigation/main_shell.dart';
import 'login_screen.dart';

class EmailCodeScreen extends StatefulWidget {
  const EmailCodeScreen({super.key});
  @override
  State<EmailCodeScreen> createState() => _EmailCodeScreenState();
}

class _EmailCodeScreenState extends State<EmailCodeScreen> {
  final _code = TextEditingController();
  bool _sent = false;
  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Confirmar acesso')),
      body: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Confirme o código destinado a ${controller.admin?.email ?? 'seu e-mail'}. Os dados administrativos só serão liberados depois da confirmação.',
            ),
            const SizedBox(height: 16),
            Text(
              buildFirebaseEnvironment == FirebaseEnvironment.local
                  ? 'Neste ambiente local, a mensagem fica na coleção platformEmailOutbox do painel do banco, conforme o README. Nenhum e-mail real é enviado.'
                  : 'Nesta versão de demonstração, nenhum e-mail é enviado: o código fica na coleção platformEmailOutbox, no console do Firebase.',
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: controller.busy
                  ? null
                  : () async {
                      if (await controller.requestEmailCode() && mounted) {
                        setState(() => _sent = true);
                      }
                    },
              child: Text(
                _sent ? 'Solicitar outro código' : 'Solicitar código',
              ),
            ),
            if (_sent) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Código de seis números',
                ),
              ),
              FilledButton(
                onPressed: controller.busy
                    ? null
                    : () async {
                        if (await controller.verifyEmailCode(_code.text) &&
                            context.mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const MainShell(),
                            ),
                            (_) => false,
                          );
                        }
                      },
                child: const Text('Confirmar código'),
              ),
            ],
            if (controller.error != null) Text(controller.error!),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                controller.signOut();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              },
              child: const Text('Sair'),
            ),
          ],
        ),
      ),
    );
  }
}
