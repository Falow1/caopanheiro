import 'package:flutter/material.dart';
import 'package:caopanheiro_core/caopanheiro_core.dart' show localBuildNote;
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppContentCard, AppTextStyles;

import '../../core/theme/app_theme.dart';
import '../../core/widgets/confirm_dialogs.dart';
import '../../state/app_scope.dart';
import '../navigation/tutor_wide_layout.dart';
import 'auth_welcome_layout.dart';
import 'login_screen.dart';

class CompanyAccessScreen extends StatefulWidget {
  const CompanyAccessScreen({super.key});
  @override
  State<CompanyAccessScreen> createState() => _CompanyAccessScreenState();
}

class _CompanyAccessScreenState extends State<CompanyAccessScreen> {
  late final _code = TextEditingController(
    text: AppScope.of(context).pendingInvite ?? '',
  );
  String? _message;
  bool _autoTried = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryPendingInvite());
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  /// An invite opened by link is accepted once the e-mail is confirmed,
  /// without asking the tutor to copy the code.
  Future<void> _tryPendingInvite() async {
    final controller = AppScope.of(context);
    if (_autoTried ||
        controller.pendingInvite == null ||
        !controller.emailVerified) {
      return;
    }
    _autoTried = true;
    await controller.acceptLink(controller.pendingInvite!);
  }

  Future<void> _confirmSignOut() async {
    if (!await confirmSignOut(context) || !mounted) return;
    AppScope.of(context).signOut(forgetInvite: true);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _resend() async {
    final controller = AppScope.of(context);
    if (await controller.sendVerification() && mounted) {
      setState(
        () => _message =
            'E-mail de confirmação enviado.'
            '${localBuildNote('No ambiente local, o link aparece no terminal do Auth Emulator.')}',
      );
    }
  }

  Future<void> _checkVerified() async {
    final controller = AppScope.of(context);
    setState(() => _message = null);
    await controller.refresh();
    if (!mounted) return;
    if (!controller.emailVerified) {
      setState(
        () => _message =
            'Ainda não identificamos a confirmação. Abra o link enviado e tente de novo.',
      );
      return;
    }
    await _tryPendingInvite();
  }

  /// Without a petshop chosen there is no live refresh: the button looks for
  /// a link the petshop released (an approved return, for example).
  Future<void> _refreshLinks() async {
    final controller = AppScope.of(context);
    final before = {for (final company in controller.companies) company.id};
    setState(() => _message = null);
    final done = await controller.refresh();
    if (!mounted || !done) return;
    final found = controller.companies.any(
      (company) => !before.contains(company.id),
    );
    if (!found) setState(() => _message = 'Nenhum vínculo novo.');
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final verified = controller.emailVerified;
    // With a mouse there is nothing to touch.
    final tap = tutorWide(context) ? 'clique' : 'toque';
    return AuthWelcomeLayout(
      title: 'Bom ter você\npor aqui.',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Acesso ao petshop'),
          actions: [
            IconButton(
              tooltip: 'Sair',
              onPressed: controller.busy ? null : _confirmSignOut,
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (controller.linkNotice != null) ...[
                  Text(
                    controller.linkNotice!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                  const SizedBox(height: 16),
                ],
                if (controller.returnRequested) ...[
                  const Text(
                    'Pedido enviado. O petshop precisa liberar o seu retorno. Quando ele aprovar, o petshop aparece aqui: use Atualizar vínculos.',
                    style: TextStyle(color: AppColors.primary),
                  ),
                  const SizedBox(height: 16),
                ],
                if (controller.companies.isNotEmpty) ...[
                  Text(
                    'Selecione o petshop',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  for (final company in controller.companies)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: OutlinedButton(
                        onPressed: controller.busy
                            ? null
                            : () => controller.selectCompany(company.id),
                        child: Row(
                          children: [
                            Expanded(child: Text(company.name)),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                ],
                Text(
                  controller.companies.isEmpty
                      ? 'Vincule seu cadastro ao petshop'
                      : 'Vincular outro petshop',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Use o link ou o QR Code do petshop, ou o convite que ele enviou para você. O e-mail da sua conta precisa estar confirmado.',
                ),
                const SizedBox(height: 16),
                AppContentCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            verified
                                ? Icons.verified_outlined
                                : Icons.mark_email_unread_outlined,
                            color: verified
                                ? AppColors.primary
                                : AppColors.muted,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              verified
                                  ? '1. E-mail confirmado'
                                  : '1. Confirme seu e-mail',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      if (!verified) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Abra o link que enviamos para o seu e-mail e depois $tap em "Já confirmei".',
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: controller.busy ? null : _checkVerified,
                          child: const Text('Já confirmei'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: controller.busy ? null : _resend,
                          child: const Text('Reenviar e-mail de confirmação'),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AppContentCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '2. Informe o convite',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _code,
                        enabled: !controller.busy,
                        decoration: const InputDecoration(
                          labelText: 'Link ou código do convite',
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Não recebeu o convite? Confira as redes sociais do petshop, onde muitos divulgam o link ou o QR Code, ou fale direto com ele.',
                        style: AppTextStyles.caption,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: controller.busy || !verified
                            ? null
                            : () async {
                                if (await controller.acceptLink(_code.text) &&
                                    mounted) {
                                  _code.clear();
                                }
                              },
                        child: const Text('Vincular petshop'),
                      ),
                      if (!verified) ...[
                        const SizedBox(height: 6),
                        const Text(
                          'Disponível depois de confirmar o e-mail.',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                TutorRefreshButton(
                  label: 'Atualizar vínculos',
                  onRefresh: _refreshLinks,
                  loading: controller.busy,
                ),
                if (_message != null) Text(_message!),
                if (controller.error != null)
                  Text(
                    controller.error!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
