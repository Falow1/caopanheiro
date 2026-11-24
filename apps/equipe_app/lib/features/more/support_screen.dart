import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppContentCard, AppTextStyles;
import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/live_screen_reload.dart';
import '../../core/widgets.dart';
import '../../state/app_scope.dart';
import 'company_extras.dart';

String _moment(DateTime value) => '${date(value)} ${time(value)}';

/// Requests from the managers of this petshop to the platform administration.
/// Messages stay inside the applications; no e-mail is sent.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});
  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> with LiveScreenReload {
  List<SupportTicket>? _tickets;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void liveScreenReload() {
    if (!_loading) _load(quiet: true);
  }

  /// [quiet]: live refresh, without loading state; a failure keeps the list.
  Future<void> _load({bool quiet = false}) async {
    if (quiet) {
      try {
        final rows = await AppScope.of(context).loadSupportTickets();
        if (mounted) setState(() => _tickets = rows);
      } catch (_) {}
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await AppScope.of(context).loadSupportTickets();
      if (mounted) setState(() => _tickets = rows);
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Não foi possível consultar os pedidos. Confira a conexão.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final tickets = _tickets ?? const <SupportTicket>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Suporte da plataforma')),
      body: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Envie uma dúvida ou um problema à administração da plataforma. A resposta aparece aqui e nos avisos; nenhum e-mail é enviado.',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: controller.busy || controller.readOnly
                  ? null
                  : () => _open(const SupportRequestFormScreen()),
              icon: const Icon(Icons.add_comment_outlined),
              label: const Text('Novo pedido de suporte'),
            ),
            const SizedBox(height: 20),
            if (_loading && _tickets == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_error != null) ...[
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _loading ? null : _load,
                child: const Text('Tentar novamente'),
              ),
            ],
            if (_tickets != null && tickets.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Text(
                  'Nenhum pedido de suporte enviado.',
                  textAlign: TextAlign.center,
                ),
              ),
            for (final ticket in tickets)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    title: Text(ticket.subject),
                    subtitle: Text(
                      '${ticket.statusLabel} · ${_moment(ticket.updatedAt)}',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _open(SupportTicketScreen(ticket: ticket)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SupportRequestFormScreen extends StatefulWidget {
  const SupportRequestFormScreen({super.key});
  @override
  State<SupportRequestFormScreen> createState() =>
      _SupportRequestFormScreenState();
}

class _SupportRequestFormScreenState extends State<SupportRequestFormScreen> {
  final _form = GlobalKey<FormState>();
  final _subject = TextEditingController(), _message = TextEditingController();
  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    final sent = await AppScope.of(
      context,
    ).createSupportRequest(_subject.text.trim(), _message.text.trim());
    if (!mounted || !sent) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pedido de suporte enviado.')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Novo pedido de suporte')),
      body: PageBody(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _subject,
                maxLength: 120,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Assunto'),
                validator: (value) => (value?.trim().length ?? 0) < 3
                    ? 'Informe o assunto'
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _message,
                maxLength: 2000,
                minLines: 4,
                maxLines: 10,
                decoration: const InputDecoration(
                  labelText: 'Descreva a dúvida ou o problema',
                ),
                validator: (value) => (value?.trim().length ?? 0) < 10
                    ? 'Descreva com pelo menos 10 caracteres'
                    : null,
              ),
              const SizedBox(height: 4),
              const Text(
                'Não informe senhas nem dados de clientes além do necessário.',
                style: AppTextStyles.captionMuted,
              ),
              if (controller.error != null) ...[
                const SizedBox(height: 10),
                Text(controller.error!, style: AppTextStyles.danger),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: controller.busy ? null : _send,
                child: Text(controller.busy ? 'Enviando...' : 'Enviar pedido'),
              ),
              TextButton(
                onPressed: controller.busy
                    ? null
                    : () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SupportTicketScreen extends StatefulWidget {
  const SupportTicketScreen({super.key, required this.ticket});
  final SupportTicket ticket;
  @override
  State<SupportTicketScreen> createState() => _SupportTicketScreenState();
}

class _SupportTicketScreenState extends State<SupportTicketScreen> {
  final _form = GlobalKey<FormState>();
  final _message = TextEditingController();
  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    final sent = await AppScope.of(
      context,
    ).addSupportMessage(widget.ticket.id, _message.text.trim());
    if (!mounted || !sent) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Mensagem enviada.')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context), ticket = widget.ticket;
    return Scaffold(
      appBar: AppBar(title: const Text('Pedido de suporte')),
      body: PageBody(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                ticket.subject,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(ticket.statusLabel, style: AppTextStyles.captionMuted),
              const SizedBox(height: 16),
              _Bubble(
                author: ticket.authorName,
                moment: ticket.createdAt,
                text: ticket.message,
                fromPlatform: false,
              ),
              for (final reply in ticket.replies)
                _Bubble(
                  author: reply.authorName,
                  moment: reply.at,
                  text: reply.message,
                  fromPlatform: reply.fromPlatform,
                ),
              const SizedBox(height: 12),
              if (ticket.closed)
                const Text(
                  'Este pedido foi encerrado pelo suporte. Para continuar, abra um novo pedido.',
                )
              else ...[
                TextFormField(
                  controller: _message,
                  maxLength: 2000,
                  minLines: 3,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Acrescentar mensagem',
                  ),
                  validator: (value) => (value?.trim().length ?? 0) < 3
                      ? 'Escreva a mensagem'
                      : null,
                ),
                if (controller.error != null) ...[
                  Text(controller.error!, style: AppTextStyles.danger),
                  const SizedBox(height: 8),
                ],
                FilledButton(
                  onPressed: controller.busy || controller.readOnly
                      ? null
                      : _send,
                  child: Text(
                    controller.busy ? 'Enviando...' : 'Enviar mensagem',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.author,
    required this.moment,
    required this.text,
    required this.fromPlatform,
  });
  final String author;
  final DateTime moment;
  final String text;
  final bool fromPlatform;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: AppContentCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${fromPlatform ? 'Suporte' : 'Petshop'} · $author · ${_moment(moment)}',
            style: AppTextStyles.metadata,
          ),
          const SizedBox(height: 6),
          Text(text),
        ],
      ),
    ),
  );
}
