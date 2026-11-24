import 'package:flutter/material.dart';
import 'package:caopanheiro_core/caopanheiro_core.dart' show localBuildNote;
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show
        AppGoogleButton,
        AppLoadingIndicator,
        AppPasswordRecoveryScreen,
        AppTextStyles;

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../domain/policies/tutor_invite.dart';
import '../../state/app_controller.dart';
import '../../state/app_scope.dart';
import '../navigation/main_shell.dart';
import '../navigation/tutor_wide_layout.dart';
import 'auth_welcome_layout.dart';
import 'install_invite.dart';
import 'install_support.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.install});

  /// The browser's install support; tests pass their own.
  final InstallSupport? install;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  late final _install = widget.install ?? InstallSupport.platform();
  late bool _invite = _install.offersInvite;
  bool _obscure = true;
  String? _fieldError;
  DateTime? _resetUntil;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!looksLikeEmail(_email.text) || _password.text.isEmpty) {
      setState(() => _fieldError = 'Informe seu e-mail e a senha.');
      return;
    }
    setState(() => _fieldError = null);
    final controller = AppScope.of(context);
    if (await controller.signIn(_email.text.trim(), _password.text) &&
        mounted) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const MainShell()));
    }
  }

  Future<void> _google() async {
    setState(() => _fieldError = null);
    final controller = AppScope.of(context);
    if (await controller.signInWithGoogle() && mounted) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const MainShell()));
    }
  }

  /// Recovery has its own page. The wait between requests is kept here, so
  /// leaving and reopening the page does not send another e-mail early.
  Future<void> _forgotPassword() async {
    final controller = AppScope.of(context);
    setState(() => _fieldError = null);
    await Navigator.of(context).push(
      MaterialPageRoute(
        // On wide windows, with the welcome of the other entry pages; the
        // page of the package is the same.
        builder: (_) => AuthWelcomeLayout(
          title: 'Vamos recuperar\nseu acesso.',
          message:
              'Enviamos para o seu e-mail as instruções para criar uma nova senha.',
          child: AppPasswordRecoveryScreen(
            initialEmail: _email.text,
            waitUntil: _resetUntil,
            onWaitChanged: (until) => _resetUntil = until,
            sentMessage:
                'Se houver uma conta com esse e-mail, enviaremos as instruções para criar uma nova senha.'
                '${localBuildNote('No ambiente local, o link aparece no terminal do Auth Emulator.')}',
            send: (email) async {
              final sent = await controller.requestPasswordReset(email);
              final failure = sent
                  ? null
                  : controller.error ?? 'Não foi possível enviar. Tente novamente.';
              controller.clearError();
              return failure;
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final error = _fieldError ?? controller.error;
    // On wide windows the welcome and the note are on the green at the left.
    final wide = tutorWide(context);
    final welcome = controller.pendingInvite == null
        ? 'Entre para cuidar da rotina dos seus melhores amigos.'
        : 'Você abriu um convite de petshop. Entre ou crie sua conta para concluir o vínculo.';
    const note = 'Seus dados e os dos seus pets ficam protegidos.';
    return AuthWelcomeLayout(
      title: 'Bom ter você\npor aqui.',
      message: welcome,
      note: note,
      child: _page(controller, error, wide, welcome, note),
    );
  }

  Widget _page(
    AppController controller,
    String? error,
    bool wide,
    String welcome,
    String note,
  ) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(wide ? 40 : 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!wide) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: BrandMark(),
                    ),
                    const SizedBox(height: 54),
                    Text(
                      'Bom ter você\npor aqui.',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: 12),
                    Text(welcome),
                    const SizedBox(height: 34),
                  ],
                  TextField(
                    controller: _email,
                    enabled: !controller.busy,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _password,
                    enabled: !controller.busy,
                    obscureText: _obscure,
                    autofillHints: const [AutofillHints.password],
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
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: controller.busy ? null : _forgotPassword,
                      child: const Text('Esqueci minha senha'),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      error,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: controller.busy ? null : _submit,
                    child: controller.busy
                        ? const AppLoadingIndicator.button(dimension: 22)
                        : const Text('Entrar'),
                  ),
                  if (controller.integrated) ...[
                    const SizedBox(height: 10),
                    AppGoogleButton(
                      onPressed: controller.busy ? null : _google,
                      label: 'Entrar com Google',
                    ),
                  ],
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: controller.busy
                        ? null
                        : () async {
                            // A failure of this screen (Google, for example)
                            // does not follow to the sign-up, nor back.
                            controller.clearError();
                            setState(() => _fieldError = null);
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SignupScreen(),
                              ),
                            );
                            if (mounted) controller.clearError();
                          },
                    child: const Text('Criar conta'),
                  ),
                  if (!wide) ...[
                    if (_invite) ...[
                      const SizedBox(height: 20),
                      InstallInvite(
                        support: _install,
                        onDone: () => setState(() => _invite = false),
                      ),
                      const SizedBox(height: 20),
                    ] else
                      const SizedBox(height: 34),
                    Row(
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          size: 18,
                          color: AppColors.muted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(note, style: AppTextStyles.caption),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
