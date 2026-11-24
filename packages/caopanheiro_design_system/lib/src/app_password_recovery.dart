import 'dart:async';

import 'package:flutter/material.dart';

import 'app_form_page.dart';
import 'app_states.dart';
import 'app_text_styles.dart';

/// Password recovery page shared by the apps. Presentation only: the request
/// reaches the server through [send], which returns null when the request was
/// accepted or the message to show when it failed. The confirmation text must
/// not reveal whether the e-mail has an account.
class AppPasswordRecoveryScreen extends StatefulWidget {
  const AppPasswordRecoveryScreen({
    super.key,
    required this.send,
    required this.sentMessage,
    this.initialEmail = '',
    this.intro =
        'Informe o e-mail da sua conta. Enviaremos as instruções para você criar uma nova senha.',
    this.cooldown = const Duration(seconds: 60),
    this.waitUntil,
    this.onWaitChanged,
    this.clock,
  });

  final Future<String?> Function(String email) send;
  final String sentMessage;
  final String initialEmail;
  final String intro;

  /// Minimum time between two requests from this page.
  final Duration cooldown;

  /// A wait already running, kept by the caller between visits to the page.
  final DateTime? waitUntil;
  final ValueChanged<DateTime>? onWaitChanged;
  final DateTime Function()? clock;

  @override
  State<AppPasswordRecoveryScreen> createState() =>
      _AppPasswordRecoveryScreenState();
}

class _AppPasswordRecoveryScreenState extends State<AppPasswordRecoveryScreen> {
  late final _email = TextEditingController(text: widget.initialEmail.trim());
  late DateTime? _waitUntil = widget.waitUntil;
  Timer? _clock;
  bool _sending = false;
  String? _error, _message;

  DateTime get _now => widget.clock?.call() ?? DateTime.now();
  int get _waitSeconds {
    final until = _waitUntil;
    if (until == null) return 0;
    final ms = until.difference(_now).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  @override
  void initState() {
    super.initState();
    if (_waitSeconds > 0) _tick();
  }

  @override
  void dispose() {
    _clock?.cancel();
    _email.dispose();
    super.dispose();
  }

  void _tick() {
    _clock?.cancel();
    var previous = _waitSeconds;
    _clock = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      final seconds = _waitSeconds;
      if (seconds != previous) {
        previous = seconds;
        setState(() {});
      }
      if (seconds == 0) _clock?.cancel();
    });
  }

  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  Future<void> _send() async {
    if (_sending || _waitSeconds > 0) return;
    final email = _email.text.trim().toLowerCase();
    if (!_emailPattern.hasMatch(email)) {
      setState(() {
        _message = null;
        _error = 'Informe um e-mail válido.';
      });
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
      _message = null;
    });
    final failure = await widget.send(email);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (failure != null) {
        _error = failure;
        return;
      }
      _message = widget.sentMessage;
      _waitUntil = _now.add(widget.cooldown);
      widget.onWaitChanged?.call(_waitUntil!);
    });
    if (failure == null) _tick();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = _waitSeconds;
    final blocked = _sending || seconds > 0;
    return AppFormPage(
      title: 'Recuperar senha',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.intro),
          const SizedBox(height: 18),
          TextField(
            controller: _email,
            enabled: !_sending,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            decoration: const InputDecoration(
              labelText: 'E-mail',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: AppTextStyles.danger),
          ],
          if (_message != null) ...[
            const SizedBox(height: 10),
            Text(_message!),
          ],
          if (seconds > 0) ...[
            const SizedBox(height: 10),
            Text('Você pode pedir um novo envio em $seconds s.'),
          ],
          const SizedBox(height: 22),
          FilledButton(
            onPressed: blocked ? null : _send,
            child: _sending
                ? const AppLoadingIndicator.button()
                : const Text('Enviar instruções'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _sending ? null : () => Navigator.maybePop(context),
            child: const Text('Voltar ao login'),
          ),
        ],
      ),
    );
  }
}
