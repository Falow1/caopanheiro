import 'staff_activation_screen.dart';
import 'package:flutter/material.dart';
import '../../state/app_scope.dart';
import 'staff_link_screen.dart';
import 'manager_activation_screen.dart';

class InvitationEntryScreen extends StatelessWidget {
  const InvitationEntryScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tenho um convite')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(24),
          children: [
            const Text('Como você recebeu seu convite?'),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => openStaffLinkEntry(context),
              icon: const Icon(Icons.link),
              label: const Text('Recebi um link'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const _EmailInvitationScreen(),
                ),
              ),
              icon: const Icon(Icons.manage_accounts_outlined),
              label: const Text('Convite por e-mail'),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Voltar ao login'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _EmailInvitationScreen extends StatefulWidget {
  const _EmailInvitationScreen();
  @override
  State<_EmailInvitationScreen> createState() => _EmailInvitationScreenState();
}

class _EmailInvitationScreenState extends State<_EmailInvitationScreen> {
  final _email = TextEditingController(), _password = TextEditingController();
  String? _message;
  bool _working = false;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _continue({bool instructions = false}) async {
    if (_working) return;
    final email = _email.text.trim().toLowerCase();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _message = 'Informe um e-mail válido.');
      return;
    }
    if (!instructions && _password.text.isEmpty) {
      setState(() => _message = 'Informe sua senha para continuar.');
      return;
    }
    final controller = AppScope.of(context);
    setState(() {
      _working = true;
      _message = null;
    });
    try {
      if (instructions) {
        final sent = await controller.resendManagerInvitation(email);
        if (mounted) {
          setState(
            () => _message = sent
                ? 'Se houver um convite disponível para esse e-mail, você receberá as instruções.'
                : controller.error,
          );
        }
      } else {
        final success = await controller.signIn(email, _password.text);
        if (!mounted) return;
        final manager = controller.managerActivation,
            staff = controller.staffActivation;
        if (success && (manager != null || staff != null)) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => staff != null
                  ? StaffActivationScreen(profile: staff)
                  : ManagerActivationScreen(initialProfile: manager),
            ),
          );
        } else {
          if (success) controller.signOut();
          setState(
            () => _message = success
                ? 'Nenhum convite disponível. Confira o e-mail ou peça um novo convite.'
                : controller.error,
          );
        }
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_working,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Convite por e-mail'),
        automaticallyImplyLeading: !_working,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Use o e-mail que recebeu o convite. Se ainda não definiu uma senha, solicite as instruções.',
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _email,
                  enabled: !_working,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'E-mail'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  enabled: !_working,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Senha'),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _working ? null : () => _continue(),
                  child: const Text('Continuar convite'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _working
                      ? null
                      : () => _continue(instructions: true),
                  child: const Text('Enviar instruções do convite'),
                ),
                TextButton(
                  onPressed: _working
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Voltar'),
                ),
                if (_working) const LinearProgressIndicator(),
                if (_message != null) Text(_message!),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
