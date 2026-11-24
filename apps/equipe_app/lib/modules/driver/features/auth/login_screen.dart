import '../../../../features/auth/login_screen.dart' as unified;
import '../../../../state/workforce_scope.dart';
import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppLoadingIndicator, AppTextStyles;

import '../../core/widgets.dart';
import '../../state/app_scope.dart';
import '../navigation/main_shell.dart';
import '../tenant/tenant_selection_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _login = TextEditingController();
  final _password = TextEditingController();
  bool _hidden = true;

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final controller = AppScope.of(context);
    final success = await controller.signIn(_login.text.trim(), _password.text);
    if (!mounted || !success) return;
    final destination = controller.memberships.length > 1
        ? const TenantSelectionScreen()
        : const MainShell();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (WorkforceScope.maybeOf(context) != null) {
      return const unified.LoginScreen();
    }
    final controller = AppScope.of(context);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(alignment: Alignment.centerLeft, child: Brand()),
                const SizedBox(height: 52),
                Text(
                  'Sua próxima tarefa,\nsempre clara.',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 12),
                const Text('Acesse os transportes atribuídos à sua conta.'),
                const SizedBox(height: 32),
                TextField(
                  controller: _login,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'E-mail ou usuário',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _password,
                  obscureText: _hidden,
                  onSubmitted: (_) => controller.busy ? null : _submit(),
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _hidden = !_hidden),
                      icon: Icon(
                        _hidden
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
                if (controller.error != null) ...[
                  const SizedBox(height: 10),
                  Text(controller.error!, style: AppTextStyles.danger),
                ],
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: controller.busy ? null : _submit,
                  child: controller.busy
                      ? const AppLoadingIndicator.button(dimension: 21)
                      : const Text('Entrar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
