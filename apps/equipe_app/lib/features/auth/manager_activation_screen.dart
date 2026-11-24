import 'login_screen.dart';
import 'package:caopanheiro_core/caopanheiro_core.dart'
    show
        PhoneInputFormatter,
        displayPhone,
        formatBrazilPhone,
        localBuildNote,
        phoneHint,
        phoneValidator;
import 'package:flutter/material.dart';
import '../../domain/repositories/manager_activation_repository.dart';
import '../../state/app_scope.dart';

class ManagerActivationScreen extends StatefulWidget {
  const ManagerActivationScreen({super.key, this.initialProfile});
  final ManagerActivation? initialProfile;
  @override
  State<ManagerActivationScreen> createState() =>
      _ManagerActivationScreenState();
}

class _ManagerActivationScreenState extends State<ManagerActivationScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _companyPhone = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _form = GlobalKey<FormState>();
  ManagerActivation? _profile;
  ActivationCompany? _company;
  String? _message;

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile;
    if (profile != null) {
      _profile = profile;
      _name.text = profile.name;
      _phone.text = displayPhone(profile.phone);
      if (profile.companies.isNotEmpty) _select(profile.companies.first);
    }
  }

  @override
  void dispose() {
    for (final field in [_name, _phone, _companyPhone, _city, _state]) {
      field.dispose();
    }
    super.dispose();
  }

  void _select(ActivationCompany company) {
    _company = company;
    _companyPhone.text = displayPhone(company.phone);
    _city.text = company.city;
    _state.text = company.state;
  }

  Future<void> _complete() async {
    if (!_form.currentState!.validate() || _company == null) return;
    final success = await AppScope.of(context).completeManagerActivation(
      tenantId: _company!.id,
      name: _name.text,
      phone: formatBrazilPhone(_phone.text) ?? _phone.text,
      companyPhone: formatBrazilPhone(_companyPhone.text) ?? _companyPhone.text,
      city: _city.text,
      state: _state.text,
    );
    if (!mounted || !success) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Acesso ativado. Entre com seu e-mail e senha.'),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    bool busy, {
    int min = 2,
    bool phone = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      enabled: !busy,
      keyboardType: phone ? TextInputType.phone : null,
      inputFormatters: phone ? const [PhoneInputFormatter()] : null,
      validator: phone
          ? phoneValidator
          : (value) =>
                (value?.trim().length ?? 0) < min ? 'Confira este campo' : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: phone ? phoneHint : null,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final busy = controller.busy;
    final profile = _profile;
    return PopScope(
      canPop: !busy,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) controller.signOut();
      },
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
                  if (profile == null) ...[
                    const Text('Entre com seu e-mail e senha para continuar.'),
                  ] else if (profile.companies.isEmpty) ...[
                    const Text(
                      'Nenhum convite disponível. Ele pode ter expirado, sido revogado ou já estar concluído. Solicite ao administrador do SaaS a conferência do seu vínculo.',
                    ),
                    TextButton(
                      onPressed: busy ? null : () => Navigator.pop(context),
                      child: const Text('Voltar para entrar'),
                    ),
                  ] else ...[
                    Text(profile.email),
                    const SizedBox(height: 12),
                    if (!profile.emailVerified) ...[
                      const Text(
                        'Confirme seu e-mail antes de concluir. Depois de abrir o link de verificação, toque em Concluir ativação.',
                      ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () async {
                                if (await controller
                                        .sendManagerVerification() &&
                                    mounted) {
                                  setState(
                                    () => _message =
                                        'Link de verificação solicitado.'
                                        '${localBuildNote('No ambiente local, consulte o Auth do emulador.')}',
                                  );
                                }
                              },
                        child: const Text('Enviar verificação de e-mail'),
                      ),
                    ],
                    if (profile.companies.length > 1)
                      DropdownButtonFormField<String>(
                        initialValue: _company?.id,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Petshop do convite',
                        ),
                        items: profile.companies
                            .map(
                              (c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.name),
                              ),
                            )
                            .toList(),
                        onChanged: busy
                            ? null
                            : (id) => setState(
                                () => _select(
                                  profile.companies.firstWhere(
                                    (c) => c.id == id,
                                  ),
                                ),
                              ),
                      ),
                    if (profile.companies.length == 1)
                      Text(
                        _company!.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    const SizedBox(height: 20),
                    Form(
                      key: _form,
                      child: Column(
                        children: [
                          _field(_name, 'Seu nome', busy),
                          _field(_phone, 'Seu telefone', busy, phone: true),
                          _field(
                            _companyPhone,
                            'Telefone do petshop',
                            busy,
                            phone: true,
                          ),
                          _field(_city, 'Cidade do petshop', busy),
                          _field(_state, 'UF do petshop', busy),
                        ],
                      ),
                    ),
                    const Text(
                      'Endereço de coleta e taxas podem ser configurados depois, em Mais → Administração → Transporte.',
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: busy ? null : _complete,
                      child: const Text('Concluir ativação'),
                    ),
                  ],
                  TextButton(
                    onPressed: busy
                        ? null
                        : () {
                            controller.signOut();
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                              (_) => false,
                            );
                          },
                    child: const Text('Voltar ao login'),
                  ),
                  if (busy)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: LinearProgressIndicator(),
                    ),
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(_message!),
                    ),
                  if (controller.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        controller.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
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
