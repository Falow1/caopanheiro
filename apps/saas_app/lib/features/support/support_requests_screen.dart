import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppConfirmTone, AppContentCard, AppTextStyles, showAppConfirmation;
import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../core/widgets.dart';
import '../../state/app_scope.dart';

/// Requests sent by petshop managers. Replies stay inside the applications:
/// no e-mail is sent by this screen.
class SupportRequestsScreen extends StatefulWidget {
  const SupportRequestsScreen({super.key});
  @override
  State<SupportRequestsScreen> createState() => _SupportRequestsScreenState();
}

class _SupportRequestsScreenState extends State<SupportRequestsScreen> {
  bool _loaded = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await AppScope.of(context).loadSupportRequests();
    if (mounted) setState(() => _loaded = true);
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    if (controller.admin == null) return const SizedBox.shrink();
    final requests = controller.supportRequests;
    return Scaffold(
      appBar: AppBar(title: const Text('Pedidos de suporte')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            const Text(
              'Pedidos enviados pelos gestores no aplicativo Equipe. A resposta aparece para o gestor no aplicativo; nenhum e-mail é enviado.',
              style: AppTextStyles.captionMuted,
            ),
            const SizedBox(height: 14),
            if (!_loaded && requests.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (controller.error != null && requests.isEmpty) ...[
              Text(controller.error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: controller.busy ? null : _load,
                child: const Text('Tentar novamente'),
              ),
            ] else if (requests.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  'Nenhum pedido de suporte recebido.',
                  textAlign: TextAlign.center,
                ),
              )
            else
              for (final request in requests)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              SupportRequestDetailScreen(requestId: request.id),
                        ),
                      ),
                      title: Text(
                        request.subject,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      subtitle: Text(
                        '${request.tenantName} · ${request.authorName}\n${request.statusLabel} · ${dateTime(request.updatedAt)}',
                      ),
                      isThreeLine: true,
                      leading: Icon(
                        request.waiting
                            ? Icons.mark_unread_chat_alt_outlined
                            : request.closed
                            ? Icons.check_circle_outline
                            : Icons.forum_outlined,
                        color: request.waiting
                            ? AppColors.orange
                            : AppColors.primary,
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class SupportRequestDetailScreen extends StatefulWidget {
  const SupportRequestDetailScreen({super.key, required this.requestId});
  final String requestId;
  @override
  State<SupportRequestDetailScreen> createState() =>
      _SupportRequestDetailScreenState();
}

class _SupportRequestDetailScreenState
    extends State<SupportRequestDetailScreen> {
  final _reply = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send({required bool close}) async {
    if (!_form.currentState!.validate()) return;
    final controller = AppScope.of(context);
    if (close) {
      final confirmed = await showAppConfirmation(
        context,
        title: 'Responder e encerrar o pedido?',
        message:
            'O gestor verá esta resposta e não poderá acrescentar mensagens a este pedido. Para continuar a conversa, ele precisará abrir um novo pedido.',
        confirmLabel: 'Responder e encerrar',
        tone: AppConfirmTone.danger,
      );
      if (!confirmed || !mounted) return;
    }
    final sent = await controller.replySupportRequest(
      widget.requestId,
      _reply.text.trim(),
      close: close,
    );
    if (!mounted) return;
    if (sent) {
      _reply.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(close ? 'Pedido encerrado.' : 'Resposta enviada.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    if (controller.admin == null) return const SizedBox.shrink();
    final request = controller.supportRequests
        .where((item) => item.id == widget.requestId)
        .firstOrNull;
    if (request == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pedido de suporte')),
        body: const Center(
          child: Text('Pedido indisponível. Atualize a lista.'),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Pedido de suporte')),
      body: PageBody(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                request.subject,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                '${request.tenantName} · ${request.statusLabel}',
                style: AppTextStyles.captionMuted,
              ),
              const SizedBox(height: 16),
              _Message(
                author: request.authorName,
                moment: request.createdAt,
                text: request.message,
                fromPlatform: false,
              ),
              for (final reply in request.replies)
                _Message(
                  author: reply.authorName,
                  moment: reply.at,
                  text: reply.message,
                  fromPlatform: reply.fromPlatform,
                ),
              const SizedBox(height: 12),
              if (request.closed)
                const Text(
                  'Pedido encerrado. O gestor pode abrir um novo pedido pelo aplicativo Equipe.',
                )
              else ...[
                TextFormField(
                  controller: _reply,
                  maxLength: 2000,
                  minLines: 3,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Resposta ao gestor',
                  ),
                  validator: (value) => (value?.trim().length ?? 0) < 3
                      ? 'Escreva a resposta'
                      : null,
                ),
                if (controller.error != null) ...[
                  Text(controller.error!, style: AppTextStyles.danger),
                  const SizedBox(height: 8),
                ],
                FilledButton(
                  onPressed: controller.busy || controller.readOnly
                      ? null
                      : () => _send(close: false),
                  child: const Text('Enviar resposta'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: controller.busy || controller.readOnly
                      ? null
                      : () => _send(close: true),
                  child: const Text('Responder e encerrar'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
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
            '${fromPlatform ? 'Suporte' : 'Gestor'} · $author · ${dateTime(moment)}',
            style: AppTextStyles.metadata,
          ),
          const SizedBox(height: 6),
          Text(text),
        ],
      ),
    ),
  );
}
