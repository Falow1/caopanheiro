import 'package:caopanheiro_core/caopanheiro_core.dart'
    show PhoneInputFormatter, formatBrazilPhone, phoneHint, phoneValidator;
import 'package:flutter/material.dart';
import '../../domain/repositories/staff_link_repository.dart';
import '../../state/app_scope.dart';
import 'login_screen.dart';

class StaffLinkScreen extends StatefulWidget {
  const StaffLinkScreen({super.key, required this.link});
  final StaffLink link;
  @override
  State<StaffLinkScreen> createState() => _StaffLinkScreenState();
}

class _StaffLinkScreenState extends State<StaffLinkScreen> {
  final _email = TextEditingController(),
      _password = TextEditingController(),
      _name = TextEditingController(),
      _phone = TextEditingController(),
      _specialty = TextEditingController();
  final _authForm = GlobalKey<FormState>(),
      _profileForm = GlobalKey<FormState>();
  Map<String, dynamic>? _info;
  bool _started = false, _createAccount = true, _authenticated = false;
  String? _message;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final info = await AppScope.of(context).inspectStaffLink(widget.link);
        if (mounted) setState(() => _info = info);
      });
    }
  }

  @override
  void dispose() {
    for (final c in [_email, _password, _name, _phone, _specialty]) {
      c.dispose();
    }
    super.dispose();
  }

  void _leave() {
    AppScope.of(context).signOut();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _authenticate() async {
    if (!_authForm.currentState!.validate()) return;
    final ok = await AppScope.of(context).authenticateStaffLink(
      widget.link,
      email: _email.text,
      password: _password.text,
      createAccount: _createAccount,
    );
    if (mounted && ok) setState(() => _authenticated = true);
  }

  Future<void> _accept() async {
    if (!_profileForm.currentState!.validate()) return;
    final professional = (_info?['roles'] as List? ?? []).contains(
      'PROFESSIONAL',
    );
    final ok = await AppScope.of(context).acceptStaffLink(
      widget.link,
      name: _name.text,
      phone: formatBrazilPhone(_phone.text) ?? _phone.text,
      specialty: professional ? _specialty.text : null,
    );
    if (!mounted || !ok) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Vínculo confirmado. Entre com sua conta para acessar o petshop.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context), info = _info;
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(title: const Text('Convite para o petshop')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (info != null) ...[
                    Text(
                      (info['companies'] as List?)
                              ?.map((company) => company['name'])
                              .join(' · ') ??
                          info['companyName'] as String,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      info['kind'] == 'MANAGEMENT'
                          ? 'Acesso à gestão deste petshop. Somente o gestor principal administra os vínculos.'
                          : 'Você recebeu um convite para integrar a equipe deste petshop.',
                    ),
                    const SizedBox(height: 20),
                    if (!_authenticated) ...[
                      const Text(
                        'Seu e-mail e sua senha não serão mostrados ao gestor.',
                      ),
                      const SizedBox(height: 12),
                      Form(
                        key: _authForm,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _email,
                              enabled: !c.busy,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Seu e-mail',
                              ),
                              validator: (v) =>
                                  RegExp(
                                    r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                  ).hasMatch(v?.trim() ?? '')
                                  ? null
                                  : 'Informe um e-mail válido',
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _password,
                              enabled: !c.busy,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Sua senha',
                              ),
                              validator: (v) => (v?.length ?? 0) < 6
                                  ? 'Use ao menos seis caracteres'
                                  : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: c.busy ? null : _authenticate,
                        child: Text(
                          _createAccount
                              ? 'Criar minha conta'
                              : 'Entrar com minha conta',
                        ),
                      ),
                      TextButton(
                        onPressed: c.busy
                            ? null
                            : () => setState(
                                () => _createAccount = !_createAccount,
                              ),
                        child: Text(
                          _createAccount
                              ? 'Já tenho uma conta'
                              : 'Ainda não tenho conta',
                        ),
                      ),
                    ] else ...[
                      Text(_email.text.trim()),
                      const SizedBox(height: 12),
                      if (!c.invitationEmailVerified) ...[
                        const Text(
                          'Confirme seu e-mail pelo link de verificação antes de aceitar o convite.',
                        ),
                        TextButton(
                          onPressed: c.busy
                              ? null
                              : () async {
                                  if (await c.sendLinkVerification() &&
                                      mounted) {
                                    setState(
                                      () => _message =
                                          'Solicitação de verificação registrada.',
                                    );
                                  }
                                },
                          child: const Text('Solicitar verificação de e-mail'),
                        ),
                      ],
                      Form(
                        key: _profileForm,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _name,
                              enabled: !c.busy,
                              decoration: const InputDecoration(
                                labelText: 'Seu nome',
                              ),
                              validator: (v) => (v?.trim().length ?? 0) < 2
                                  ? 'Informe seu nome'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _phone,
                              enabled: !c.busy,
                              keyboardType: TextInputType.phone,
                              inputFormatters: const [PhoneInputFormatter()],
                              decoration: const InputDecoration(
                                labelText: 'Seu telefone',
                                hintText: phoneHint,
                              ),
                              validator: phoneValidator,
                            ),
                            if ((info['roles'] as List).contains(
                              'PROFESSIONAL',
                            )) ...[
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _specialty,
                                enabled: !c.busy,
                                decoration: const InputDecoration(
                                  labelText: 'Sua especialidade',
                                ),
                                validator: (v) => (v?.trim().isEmpty ?? true)
                                    ? 'Informe sua especialidade'
                                    : null,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: c.busy ? null : _accept,
                        child: const Text('Aceitar convite'),
                      ),
                    ],
                  ],
                  if (c.busy) const LinearProgressIndicator(),
                  if (c.error != null)
                    Text(
                      c.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  if (_message != null) Text(_message!),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: c.busy ? null : _leave,
                    child: const Text('Voltar ao login'),
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

Future<void> openStaffLinkEntry(BuildContext context) async {
  final link = await showDialog<StaffLink>(
    context: context,
    builder: (_) => const _StaffLinkEntryDialog(),
  );
  if (context.mounted && link != null) {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StaffLinkScreen(link: link)),
    );
  }
}

class _StaffLinkEntryDialog extends StatefulWidget {
  const _StaffLinkEntryDialog();
  @override
  State<_StaffLinkEntryDialog> createState() => _StaffLinkEntryDialogState();
}

class _StaffLinkEntryDialogState extends State<_StaffLinkEntryDialog> {
  final _input = TextEditingController(), _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Abrir convite'),
    content: Form(
      key: _form,
      child: TextFormField(
        controller: _input,
        decoration: const InputDecoration(labelText: 'Cole o link do convite'),
        validator: (v) =>
            StaffLink.tryParse(v) == null ? 'Confira o link recebido' : null,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, StaffLink.tryParse(_input.text));
          }
        },
        child: const Text('Abrir convite'),
      ),
    ],
  );
}
