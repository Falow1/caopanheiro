import 'dart:async';
import 'package:flutter/material.dart';
import 'login_code_gate.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show
        AppGoogleButton,
        AppLoadingIndicator,
        AppPasswordRecoveryScreen,
        AppTextStyles;
import '../../core/widgets.dart';
import '../../state/app_controller.dart';
import '../../state/app_scope.dart';
import '../navigation/unified_shell.dart';
import '../navigation/main_shell.dart';
import 'invitation_entry_screen.dart';
import 'company_selection_screen.dart';
import 'access_paused_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.clock});
  final DateTime Function()? clock;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController(), _password = TextEditingController();
  Timer? _clock;
  bool _hidden = true, _submitting = false;
  String? _error;
  DateTime? _waitUntil, _mailUntil;
  DateTime get _now => widget.clock?.call() ?? DateTime.now();
  String get _contact => _email.text.trim().toLowerCase();
  bool get _validEmail =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_contact);
  int get _waitMs => _waitUntil == null
      ? 0
      : (_waitUntil!.difference(_now).inMilliseconds).clamp(0, 3600000);
  void _tick() {
    _clock?.cancel();
    var previousSeconds = (_waitMs / 1000).ceil();
    _clock = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      final seconds = (_waitMs / 1000).ceil();
      if (seconds != previousSeconds) {
        previousSeconds = seconds;
        setState(() {});
      }
      if (_waitMs == 0) _clock?.cancel();
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Messages change only when a button is tapped: each attempt starts by
  /// dropping the screen message and the controller's previous failure, so
  /// typing never brings an older error back.
  void _startAttempt(AppController controller) {
    controller.clearError();
    _error = null;
  }

  /// Recovery has its own page; the wait between requests is kept here so
  /// leaving and reopening the page does not allow a new e-mail early.
  Future<void> _recover() async {
    final controller = AppScope.of(context);
    setState(() => _startAttempt(controller));
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AppPasswordRecoveryScreen(
          initialEmail: _email.text,
          clock: widget.clock,
          waitUntil: _mailUntil,
          onWaitChanged: (until) => _mailUntil = until,
          sentMessage:
              'Se houver acesso disponível para esse e-mail, você receberá as instruções.',
          send: (email) async {
            final sent = await controller.requestManagerPassword(email);
            final failure = sent
                ? null
                : controller.error ??
                      'Não foi possível enviar. Tente novamente.';
            controller.clearError();
            return failure;
          },
        ),
      ),
    );
  }

  Future<void> _login() async {
    final controller = AppScope.of(context);
    if (controller.busy || _submitting || _waitMs > 0) return;
    if (!_validEmail) {
      setState(() {
        _startAttempt(controller);
        _error = 'Informe um e-mail válido.';
      });
      return;
    }
    final email = _contact, password = _password.text;
    setState(() {
      _submitting = true;
      _startAttempt(controller);
    });
    try {
      if (password.isEmpty) {
        setState(() => _error = 'E-mail ou senha incorretos.');
        return;
      }
      final success = await controller.signIn(email, password);
      if (!mounted) return;
      if (success &&
          (controller.staffActivation != null ||
              controller.managerActivation != null)) {
        controller.signOut();
        setState(
          () => _error = 'Para aceitar seu convite, toque em Tenho um convite.',
        );
        return;
      }
      if (success) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => LoginCodeGate(
              email: _email.text.trim(),
              child: controller.pausedAccess.isNotEmpty
                  ? const AccessPausedScreen()
                  : controller.catalogOnly && controller.user == null
                  ? const CompanySelectionScreen()
                  : controller.unified
                  ? const UnifiedShell()
                  : MainShell(initialIndex: controller.catalogOnly ? 2 : 0),
            ),
          ),
        );
      } else {
        setState(() {
          _waitUntil = controller.loginRetryUntil;
          _password.clear();
        });
        _tick();
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Google replaces only the password: an invitation still goes through
  /// Tenho um convite and an account without link is refused by the server.
  Future<void> _google() async {
    final controller = AppScope.of(context);
    if (controller.busy || _submitting || _waitMs > 0) return;
    setState(() {
      _submitting = true;
      _startAttempt(controller);
    });
    try {
      final success = await controller.signInWithGoogle();
      if (!mounted) return;
      if (success &&
          (controller.staffActivation != null ||
              controller.managerActivation != null)) {
        controller.signOut();
        setState(
          () => _error = 'Para aceitar seu convite, toque em Tenho um convite.',
        );
        return;
      }
      if (success) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => LoginCodeGate(
              email: _email.text.trim(),
              child: controller.pausedAccess.isNotEmpty
                  ? const AccessPausedScreen()
                  : controller.catalogOnly && controller.user == null
                  ? const CompanySelectionScreen()
                  : controller.unified
                  ? const UnifiedShell()
                  : MainShell(initialIndex: controller.catalogOnly ? 2 : 0),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final busy = controller.busy || _submitting;
    final seconds = (_waitMs / 1000).ceil();
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
                  'A rotina do pet shop,\nnum só lugar.',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Entre para acompanhar a agenda e cuidar da operação do dia.',
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _email,
                  enabled: !busy,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  onEditingComplete: () => FocusScope.of(context).nextFocus(),
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _password,
                  enabled: !busy,
                  obscureText: _hidden,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _login(),
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
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: busy ? null : _recover,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(48, 48),
                      textStyle: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    child: const Text('Esqueci minha senha'),
                  ),
                ),
                if ((_error ?? controller.error) != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error ?? controller.error!,
                    style: AppTextStyles.danger,
                  ),
                ],
                if (seconds > 0) ...[
                  const SizedBox(height: 10),
                  Text('Tente novamente em $seconds s.'),
                ],
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: busy || seconds > 0 ? null : _login,
                  child: busy
                      ? const AppLoadingIndicator.button(dimension: 21)
                      : const Text('Entrar'),
                ),
                if (controller.googleAvailable) ...[
                  const SizedBox(height: 10),
                  AppGoogleButton(
                    label: 'Entrar com Google',
                    onPressed: busy || seconds > 0 ? null : _google,
                  ),
                ],
                TextButton(
                  onPressed: busy
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const InvitationEntryScreen(),
                          ),
                        ),
                  child: const Text('Tenho um convite'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
