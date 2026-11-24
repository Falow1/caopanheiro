import '../../../../features/auth/login_screen.dart' as unified;
import '../../../../state/workforce_scope.dart';
import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppLoadingIndicator, AppTextStyles;

import '../../core/widgets.dart';
import '../../state/app_scope.dart';
import '../navigation/main_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final controller = AppScope.of(context);
    final success = await controller.signIn(_identifier.text, _password.text);
    if (success && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    }
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
                const SizedBox(height: 54),
                Text(
                  'Seu dia de trabalho,\nmais simples.',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Acompanhe seus atendimentos e registre cada etapa.',
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _identifier,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Usuário ou e-mail',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _password,
                  obscureText: _obscure,
                  onSubmitted: (_) => controller.busy ? null : _submit(),
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
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
