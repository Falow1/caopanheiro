import 'package:caopanheiro_core/caopanheiro_core.dart'
    show
        PhoneInputFormatter,
        displayPhone,
        formatBrazilPhone,
        phoneHint,
        phoneValidator;
import 'package:flutter/material.dart';
import '../../domain/models.dart';
import '../../domain/repositories/staff_invitation_repository.dart';
import '../../state/app_scope.dart';
import 'login_screen.dart';

class StaffActivationScreen extends StatefulWidget {
  const StaffActivationScreen({super.key, required this.profile});
  final StaffActivation profile;
  @override
  State<StaffActivationScreen> createState() => _StaffActivationScreenState();
}

class _StaffActivationScreenState extends State<StaffActivationScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _phone;
  String? _tenantId, _message;
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile.name);
    _phone = TextEditingController(text: displayPhone(widget.profile.phone));
    if (widget.profile.companies.isNotEmpty) {
      _tenantId = widget.profile.companies.first['id'] as String;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _leave() {
    AppScope.of(context).signOut();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _complete() async {
    if (!_form.currentState!.validate() || _tenantId == null) return;
    final success = await AppScope.of(context).completeStaffActivation(
      tenantId: _tenantId!,
      name: _name.text,
      phone: formatBrazilPhone(_phone.text) ?? _phone.text,
    );
    if (!mounted || !success) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Cadastro concluído. Entre com seu e-mail e senha.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context), profile = widget.profile;
    final companies = profile.companies;
    final company = companies.where((v) => v['id'] == _tenantId).firstOrNull;
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(title: const Text('Complete seu cadastro')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(profile.email),
                  const SizedBox(height: 16),
                  if (companies.length > 1)
                    DropdownButtonFormField<String>(
                      initialValue: _tenantId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Petshop do convite',
                      ),
                      items: companies
                          .map(
                            (v) => DropdownMenuItem(
                              value: v['id'] as String,
                              child: Text(v['name'] as String),
                            ),
                          )
                          .toList(),
                      onChanged: c.busy
                          ? null
                          : (v) => setState(() => _tenantId = v),
                    ),
                  if (company != null) ...[
                    Text(
                      company['name'] as String,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      (company['roles'] as List)
                          .map((v) => TenantRole.fromApi(v as String).label)
                          .join(' · '),
                    ),
                  ],
                  if (!profile.emailVerified) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Confirme seu e-mail antes de aceitar o convite. Depois de abrir o link de verificação, conclua o cadastro.',
                    ),
                    TextButton(
                      onPressed: c.busy
                          ? null
                          : () async {
                              if (await c.sendStaffVerification() && mounted) {
                                setState(
                                  () => _message =
                                      'Solicitação de verificação registrada.',
                                );
                              }
                            },
                      child: const Text('Verificar meu e-mail'),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Form(
                    key: _form,
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: c.busy || company == null ? null : _complete,
                    child: const Text('Aceitar convite e concluir cadastro'),
                  ),
                  TextButton(
                    onPressed: c.busy ? null : _leave,
                    child: const Text('Voltar ao login'),
                  ),
                  if (c.busy) const LinearProgressIndicator(),
                  if (_message != null) Text(_message!),
                  if (c.error != null)
                    Text(
                      c.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
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
