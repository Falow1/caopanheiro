import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_content_card.dart';
import 'app_text_styles.dart';

/// The second step of the login in every app: six numbers sent by e-mail,
/// typed in six boxes. [onSkip] adds the demonstration exit, explained in
/// [demoNote], for the apps whose server does not require the code yet.
class AppCodeVerificationPage extends StatefulWidget {
  const AppCodeVerificationPage({
    super.key,
    required this.destination,
    required this.onRequest,
    required this.onVerify,
    required this.onSignOut,
    this.onSkip,
    this.demoNote,
    this.error,
    this.busy = false,
  });

  /// E-mail that receives the code.
  final String destination;

  /// Asks the server for a new code; true when it was created.
  final Future<bool> Function() onRequest;

  /// Checks the six numbers; true when they match.
  final Future<bool> Function(String code) onVerify;
  final VoidCallback onSignOut;
  final VoidCallback? onSkip;
  final String? demoNote;
  final String? error;
  final bool busy;

  @override
  State<AppCodeVerificationPage> createState() =>
      _AppCodeVerificationPageState();
}

class _AppCodeVerificationPageState extends State<AppCodeVerificationPage> {
  final _code = TextEditingController();
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() {}));
    // The first code goes out as the page opens.
    WidgetsBinding.instance.addPostFrameCallback((_) => _request());
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    final sent = await widget.onRequest();
    if (mounted && sent) setState(() => _sent = true);
  }

  Future<void> _verify() async {
    if (_code.text.length != 6 || widget.busy) return;
    final ok = await widget.onVerify(_code.text);
    if (!ok && mounted) _code.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final digits = _code.text;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: AppColors.mint,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mark_email_read_outlined,
                        size: 36,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Confirme que é você',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _sent
                        ? 'Enviamos um código de 6 números para ${widget.destination}.'
                        : 'Vamos enviar um código de 6 números para ${widget.destination}.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 28),
                  // Six boxes over one field: paste, keyboard and screen
                  // readers keep working on the field itself.
                  Semantics(
                    label: 'Código de 6 números',
                    child: Stack(
                      children: [
                        Row(
                          children: [
                            for (var index = 0; index < 6; index++) ...[
                              if (index > 0) const SizedBox(width: 8),
                              Expanded(
                                child: AspectRatio(
                                  aspectRatio: 0.85,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: AppColors.paper,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        width: index == digits.length ? 2 : 1,
                                        color: index == digits.length
                                            ? AppColors.primary
                                            : AppColors.line,
                                      ),
                                    ),
                                    child: Text(
                                      index < digits.length
                                          ? digits[index]
                                          : '',
                                      style: theme.textTheme.headlineSmall,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        // Let the field handle taps even when Android has hidden
                        // the keyboard while keeping focus.
                        Positioned.fill(
                          child: Opacity(
                            opacity: 0,
                            alwaysIncludeSemantics: true,
                            child: TextField(
                              key: const ValueKey('code-field'),
                              controller: _code,
                              autofocus: true,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(6),
                              ],
                              onChanged: (value) {
                                if (value.length == 6) _verify();
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      widget.error!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.danger,
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: digits.length == 6 && !widget.busy
                        ? _verify
                        : null,
                    child: widget.busy
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Confirmar código'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: widget.busy ? null : _request,
                    child: Text(
                      _sent ? 'Enviar outro código' : 'Enviar código',
                    ),
                  ),
                  if (widget.demoNote != null || widget.onSkip != null) ...[
                    const SizedBox(height: 20),
                    AppContentCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  widget.demoNote ??
                                      'Versão de demonstração: o e-mail com o código ainda não é enviado.',
                                ),
                              ),
                            ],
                          ),
                          if (widget.onSkip != null) ...[
                            const SizedBox(height: 12),
                            OutlinedButton(
                              key: const ValueKey('code-skip'),
                              onPressed: widget.busy ? null : widget.onSkip,
                              child: const Text('Continuar sem código'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: widget.onSignOut,
                    child: const Text('Sair'),
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
