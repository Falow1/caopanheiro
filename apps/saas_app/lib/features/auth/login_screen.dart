import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppGoogleButton, AppLoadingIndicator, AppTextStyles;

import '../../core/app_theme.dart';
import '../../core/widgets.dart';
import '../../state/app_scope.dart';
import '../navigation/main_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hidden = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final controller = AppScope.of(context);
    if (await controller.signIn(_email.text, _password.text) && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    }
  }

  Future<void> _google() async {
    final controller = AppScope.of(context);
    if (await controller.signInWithGoogle() && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  'Sua plataforma,\nsob controle.',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Acesso exclusivo para administradores da plataforma.',
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'E-mail administrativo',
                    prefixIcon: Icon(Icons.admin_panel_settings_outlined),
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
                if (controller.googleAvailable) ...[
                  const SizedBox(height: 10),
                  AppGoogleButton(
                    label: 'Entrar com Google',
                    onPressed: controller.busy ? null : _google,
                  ),
                ],
                const SizedBox(height: 20),
                const Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 18,
                      color: AppColors.muted,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sessão administrativa protegida e auditada.',
                        style: AppTextStyles.caption,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
