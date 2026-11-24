import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppButtonStyles;

class DeleteOwnAccountButton extends StatelessWidget {
  const DeleteOwnAccountButton({
    super.key,
    required this.onDelete,
    required this.error,
    required this.onDeleted,
    this.enabled = true,
  });
  final Future<bool> Function(String password) onDelete;
  final String? Function() error;
  final VoidCallback onDeleted;
  final bool enabled;
  @override
  Widget build(BuildContext context) => TextButton.icon(
    style: AppButtonStyles.dangerText,
    onPressed: !enabled
        ? null
        : () async {
            final deleted = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (_) =>
                  _DeleteAccountDialog(onDelete: onDelete, error: error),
            );
            if (deleted == true && context.mounted) onDeleted();
          },
    icon: const Icon(Icons.person_remove_outlined),
    label: const Text('Excluir minha conta'),
  );
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.onDelete, required this.error});
  final Future<bool> Function(String password) onDelete;
  final String? Function() error;
  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _password = TextEditingController();
  bool _confirmed = false, _busy = false;
  String? _error;
  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (!_confirmed || _password.text.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    bool ok = false;
    try {
      ok = await widget.onDelete(_password.text);
    } catch (_) {
      _error = 'Não foi possível confirmar a exclusão. Tente novamente.';
    }
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _busy = false;
      _error ??= widget.error() ?? 'Não foi possível excluir a conta.';
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Excluir minha conta?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Esta ação é permanente: exclui sua conta de acesso e seu perfil pessoal e retira seus vínculos em todos os petshops. Cadastros e históricos operacionais dos petshops poderão ser preservados.\n\nA conta de gestor principal só pode ser excluída pela administração do Cãopanheiro. Atendimentos e entregas abertos precisam ser concluídos ou cancelados/reatribuídos.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _password,
              obscureText: true,
              enabled: !_busy,
              enableSuggestions: false,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Sua senha atual'),
              onChanged: (_) => setState(() {}),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _confirmed,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _confirmed = value ?? false),
              title: const Text(
                'Entendo que a exclusão é permanente e afeta minha conta em todos os petshops.',
              ),
            ),
            if (_error != null) Text(_error!),
            if (_busy) const LinearProgressIndicator(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: AppButtonStyles.dangerFilled,
          onPressed: _busy || !_confirmed || _password.text.isEmpty
              ? null
              : _delete,
          child: const Text('Excluir definitivamente'),
        ),
      ],
    ),
  );
}
