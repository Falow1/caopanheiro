import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show
        AppConfirmTone,
        AppDimensions,
        AppScreenTips,
        AppStatusBadge,
        AppTextStyles,
        AppTourTarget,
        showAppConfirmation;

import '../../core/app_theme.dart';
import '../../core/file_saver.dart';
import '../../core/formatters.dart' as fmt;
import '../../core/image_sharer.dart';
import '../../core/screen_tips.dart';
import '../../core/team_layout.dart';
import '../../domain/policies/tutor_invite_link.dart';
import '../../domain/repositories/tutor_join_link_repository.dart';
import '../../state/app_scope.dart';
import 'invite_export.dart';
import 'invite_poster.dart';
import 'invite_qr.dart';

/// The petshop's fixed invite link: any tutor who opens it enters or creates
/// the account and is registered here. The management with the Customers
/// area sees and copies it; only the principal manager disables, enables or
/// replaces it and decides the return of tutors this petshop unlinked.
class TutorJoinLinkScreen extends StatefulWidget {
  const TutorJoinLinkScreen({
    super.key,
    this.tutorAppUrl = configuredTutorAppUrl,
    this.sharer = const PlatformImageSharer(),
    this.saver = const PlatformFileSaver(),
  });

  /// Address of the Tutor app; without it the area offers the code.
  final String tutorAppUrl;

  /// Share window for the QR Code and the poster images.
  final ImageSharer sharer;

  /// "Save as" window for the same images.
  final FileSaver saver;

  @override
  State<TutorJoinLinkScreen> createState() => _TutorJoinLinkScreenState();
}

class _TutorJoinLinkScreenState extends State<TutorJoinLinkScreen> {
  TutorJoinLink? _link;
  bool _loading = true;
  String? _error, _company;
  int? _liveRevision;

  /// Image being saved or shared; the four buttons lock meanwhile.
  (_InviteImage, _Export)? _working;
  InviteQr? _qr;

  /// The QR Code of [address], computed again only when the link changes.
  InviteQr _qrOf(String address) =>
      _qr?.data == address ? _qr! : _qr = InviteQr(address);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = AppScope.of(context);
    final company = controller.company?.id;
    if (_liveRevision == null || company != _company) {
      // Another petshop selected: the link on screen belongs to the previous
      // one, so it leaves at once and the area reads the new one.
      _liveRevision = controller.liveRevision;
      _company = company;
      _link = null;
      _error = null;
      _loading = company != null;
      if (company != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _load());
      }
    } else if (_liveRevision != controller.liveRevision) {
      _liveRevision = controller.liveRevision;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load(quiet: true));
    }
  }

  bool get _sameCompany => AppScope.of(context).company?.id == _company;

  /// The petshop shown in the confirmation is still the selected one.
  bool _still(String companyId) =>
      mounted && AppScope.of(context).company?.id == companyId;

  Future<void> _load({bool quiet = false}) async {
    if (!mounted) return;
    final controller = AppScope.of(context);
    if (!quiet) setState(() => _loading = true);
    final link = await controller.loadTutorJoinLink(quiet: quiet);
    if (!mounted || !_sameCompany) return;
    setState(() {
      _loading = false;
      if (link != null) {
        _link = link;
        _error = null;
      } else if (!quiet) {
        _error =
            controller.error ?? 'Não foi possível abrir o link de convite.';
      }
    });
  }

  // The result of the last action replaces the previous message at once.
  void _show(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _copy(String value, String message) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) _show(message);
  }

  /// Prepares the image and hands it to the "Save as" window or to the
  /// share window.
  Future<void> _export(
    _InviteImage image,
    _Export how,
    InviteQr qr,
    String petshop,
  ) async {
    if (_working != null) return;
    setState(() => _working = (image, how));
    try {
      final bytes = switch (image) {
        _InviteImage.qr => await qrPng(qr),
        _InviteImage.poster => await posterPng(
          InvitePoster(petshop: petshop, qr: qr),
        ),
      };
      final name = inviteFileName(image.file, petshop);
      final done = switch (how) {
        _Export.save =>
          await widget.saver.savePng(name, bytes) == SaveOutcome.saved
              ? 'Imagem salva.'
              : null,
        _Export.share =>
          await widget.sharer.sharePng(
                    name,
                    bytes,
                    title: 'Compartilhar ${image.label}',
                  ) ==
                  ShareOutcome.shared
              ? 'Imagem compartilhada.'
              : null,
      };
      // Closing the window, or no answer from the system, shows nothing.
      if (mounted && done != null) _show(done);
    } catch (_) {
      if (mounted) {
        _show(
          how == _Export.save
              ? 'Não foi possível salvar. Tente de novo.'
              : 'Não foi possível compartilhar. Tente de novo.',
        );
      }
    } finally {
      if (mounted) setState(() => _working = null);
    }
  }

  void _preview(InviteQr qr, String petshop) => showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(16),
          // Not stretched: on a short screen the poster narrows instead of
          // bending its A4 proportion.
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Pôster',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: AspectRatio(
                  aspectRatio: InvitePoster.aspectRatio,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Semantics(
                      image: true,
                      label: 'Prévia do pôster de convite',
                      child: CustomPaint(
                        painter: _PosterPainter(
                          InvitePoster(petshop: petshop, qr: qr),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Fechar'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _change(TutorJoinLinkAction action) async {
    final controller = AppScope.of(context);
    final company = controller.company;
    if (controller.busy || company == null || _link?.canManage != true) return;
    final (title, message, label, tone, done) = switch (action) {
      TutorJoinLinkAction.disable => (
        'Desativar o link?',
        'Ninguém novo entra por este link enquanto ele estiver desativado. Quem já está cadastrado continua com acesso.',
        'Desativar',
        AppConfirmTone.danger,
        'Link desativado.',
      ),
      TutorJoinLinkAction.enable => (
        'Ativar o link?',
        'Quem abrir o link volta a entrar e já fica cadastrado neste petshop.',
        'Ativar',
        AppConfirmTone.neutral,
        'Link ativado.',
      ),
      TutorJoinLinkAction.rotate => (
        'Gerar novo link?',
        'O link atual para de funcionar. QR Codes e pôsteres já impressos precisam ser trocados.',
        'Gerar novo link',
        AppConfirmTone.danger,
        'Novo link gerado. Troque os QR Codes e pôsteres já impressos.',
      ),
    };
    final confirmed = await showAppConfirmation(
      context,
      title: title,
      message: 'Petshop: ${company.name}\n\n$message',
      confirmLabel: label,
      tone: tone,
    );
    if (!confirmed || !_still(company.id)) return;
    final success = await controller.setTutorJoinLink(action);
    if (!_still(company.id)) return;
    _show(
      success ? done : controller.error ?? 'Não foi possível alterar o link.',
    );
    await _load();
  }

  Future<void> _decide(TutorReturnRequest request, bool approve) async {
    final controller = AppScope.of(context);
    final company = controller.company;
    if (controller.busy || company == null || _link?.canManage != true) return;
    final person =
        'Pessoa: ${_name(request)}\nE-mail: ${request.email}\nPetshop: ${company.name}';
    final confirmed = await showAppConfirmation(
      context,
      title: approve ? 'Aprovar o retorno?' : 'Recusar o retorno?',
      message: approve
          ? '$person\n\nA conta volta agora a ter acesso a este petshop, ligada ao cadastro de cliente.'
          : '$person\n\nO link de convite fica fechado para esta conta. Para trazer a pessoa de volta depois, use o convite individual no cadastro do cliente.',
      confirmLabel: approve ? 'Aprovar' : 'Recusar',
      tone: approve ? AppConfirmTone.neutral : AppConfirmTone.danger,
    );
    if (!confirmed || !_still(company.id)) return;
    final success = await controller.decideTutorReturn(
      request.uid,
      approve: approve,
    );
    if (!_still(company.id)) return;
    _show(
      success
          ? approve
                ? 'Retorno aprovado. O tutor já tem acesso de novo.'
                : 'Pedido recusado.'
          : controller.error ?? 'Não foi possível decidir o pedido.',
    );
    await _load();
  }

  static String _name(TutorReturnRequest request) =>
      request.name.isNotEmpty ? request.name : request.customerName ?? 'Tutor';

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final company = controller.company;
    final link = _link;
    return AppScreenTips(
      screen: TipScreens.inviteLink,
      tips: TeamTips.inviteLink,
      ready: link != null,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Link de convite'),
              if (company != null)
                Text(company.name, style: AppTextStyles.captionMuted),
            ],
          ),
        ),
        // The same page column of the other Equipe areas on wide screens.
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimensions.teamPageWidth,
            ),
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: TeamLayout.page,
                children: [
                  // One column, built whole: the tips find the management and
                  // the requests below the QR Code even on a short screen.
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_loading && link == null)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      if (_error != null) ...[
                        Text(
                          _error!,
                          style: const TextStyle(color: AppColors.danger),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (link != null) ...[
                        _status(link),
                        const SizedBox(height: 16),
                        _linkCard(link, controller.busy),
                        if (link.canManage) ...[
                          const SizedBox(height: 24),
                          _manage(link, controller.busy),
                          const SizedBox(height: 24),
                          _requests(link, controller.busy),
                        ],
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _status(TutorJoinLink link) => Row(
    children: [
      AppStatusBadge(
        label: link.active ? 'Ativo' : 'Desativado',
        background: link.active
            ? AppColors.completedSurface
            : AppColors.inactiveSurface,
        foreground: link.active
            ? AppColors.completedInk
            : AppColors.inactiveInk,
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          link.active
              ? 'Novos tutores entram por este link.'
              : 'Ninguém novo entra por este link.',
          style: AppTextStyles.captionMuted,
        ),
      ),
    ],
  );

  Widget _linkCard(TutorJoinLink link, bool busy) {
    final address = tutorInviteLink(link.code, base: widget.tutorAppUrl);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Only the link part: with the QR Code below, the whole card is
            // too tall for the tip to fit beside it on a phone.
            AppTourTarget(
              id: TipTargets.inviteLinkCopy,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Link do petshop',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Qualquer tutor que abrir este link cria a conta ou entra e já fica cadastrado neste petshop. O link não vence.',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    address == null ? 'Código do convite' : 'Link de convite',
                    style: AppTextStyles.captionMuted,
                  ),
                  SelectableText(address ?? link.code),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () => address == null
                              ? _copy(link.code, 'Código copiado.')
                              : _copy(address, 'Link copiado.'),
                    icon: Icon(
                      address == null ? Icons.copy_rounded : Icons.link_rounded,
                    ),
                    label: Text(
                      address == null ? 'Copiar código' : 'Copiar link',
                    ),
                  ),
                ],
              ),
            ),
            if (address != null) ..._qrArea(_qrOf(address), busy),
            if (address == null) ...[
              const SizedBox(height: 10),
              const Text(
                'O QR Code e o pôster ficam disponíveis quando o endereço do app do tutor estiver configurado.',
                style: AppTextStyles.captionMuted,
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _qrArea(InviteQr qr, bool busy) {
    final petshop = AppScope.of(context).company?.name ?? '';
    final locked = busy || _working != null;
    final hows = [
      if (imageSaveAvailable) _Export.save,
      if (imageShareAvailable) _Export.share,
    ];
    Widget button(_InviteImage image, _Export how) => OutlinedButton.icon(
      onPressed: locked ? null : () => _export(image, how, qr, petshop),
      icon: _working == (image, how)
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(how.icon),
      label: Text(how.label),
    );
    // Width the buttons need side by side: the longest label on one line,
    // the icon with its gap and the button's own padding (16 + 24 at most).
    final scaler = MediaQuery.textScalerOf(context);
    var label = 0.0;
    for (final how in hows) {
      final painter = TextPainter(
        text: TextSpan(
          text: how.label,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        textScaler: scaler,
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      if (painter.width > label) label = painter.width;
      painter.dispose();
    }
    final rowWidth =
        (label + scaler.scale(18 + 8) + 16 + 24 + 8) * hows.length +
        10 * (hows.length - 1);
    // Side by side when every label fits on one line, one under the other
    // on a phone.
    Widget actions(_InviteImage image) => Column(
      key: ValueKey('invite-${image.file}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(image.title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth >= rowWidth
              ? Row(
                  children: [
                    for (final (index, how) in hows.indexed) ...[
                      if (index > 0) const SizedBox(width: 10),
                      Expanded(child: button(image, how)),
                    ],
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (index, how) in hows.indexed) ...[
                      if (index > 0) const SizedBox(height: 8),
                      button(image, how),
                    ],
                  ],
                ),
        ),
      ],
    );
    return [
      const SizedBox(height: 16),
      Center(child: InviteQrView(qr: qr)),
      const SizedBox(height: 8),
      const Text(
        'A câmera do celular abre o link por este QR Code.',
        textAlign: TextAlign.center,
        style: AppTextStyles.captionMuted,
      ),
      const SizedBox(height: 12),
      if (hows.isNotEmpty) ...[
        AppTourTarget(
          id: TipTargets.inviteLinkShare,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              actions(_InviteImage.qr),
              const SizedBox(height: 14),
              actions(_InviteImage.poster),
            ],
          ),
        ),
        const SizedBox(height: 4),
      ],
      TextButton.icon(
        onPressed: () => _preview(qr, petshop),
        icon: const Icon(Icons.visibility_outlined),
        label: const Text('Ver pôster'),
      ),
    ];
  }

  Widget _manage(TutorJoinLink link, bool busy) => AppTourTarget(
    id: TipTargets.inviteLinkManage,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Gerenciar o link',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        const Text(
          'Só o gestor principal desativa ou troca o link.',
          style: AppTextStyles.captionMuted,
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: busy
              ? null
              : () => _change(
                  link.active
                      ? TutorJoinLinkAction.disable
                      : TutorJoinLinkAction.enable,
                ),
          icon: Icon(link.active ? Icons.link_off_rounded : Icons.link_rounded),
          label: Text(link.active ? 'Desativar link' : 'Ativar link'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: busy ? null : () => _change(TutorJoinLinkAction.rotate),
          icon: const Icon(Icons.autorenew_rounded),
          label: const Text('Gerar novo link'),
        ),
      ],
    ),
  );

  Widget _requests(TutorJoinLink link, bool busy) => AppTourTarget(
    id: TipTargets.inviteLinkReturns,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Pedidos de retorno',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        const Text(
          'Tutores que este petshop desvinculou e abriram o link de novo.',
          style: AppTextStyles.captionMuted,
        ),
        const SizedBox(height: 10),
        if (link.requests.isEmpty) const Text('Nenhum pedido de retorno.'),
        for (final request in link.requests)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _name(request),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (request.email.isNotEmpty) Text(request.email),
                  if (request.customerName != null &&
                      request.customerName != request.name)
                    Text(
                      'Cadastro: ${request.customerName}',
                      style: AppTextStyles.captionMuted,
                    ),
                  if (request.requestedAt != null)
                    Text(
                      'Pedido em ${fmt.date(request.requestedAt!.toLocal())}',
                      style: AppTextStyles.captionMuted,
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: busy
                              ? null
                              : () => _decide(request, false),
                          child: const Text('Recusar'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: busy ? null : () => _decide(request, true),
                          child: const Text('Aprovar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (link.moreRequests)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Há mais pedidos. Decida estes para ver os próximos.',
              style: AppTextStyles.captionMuted,
            ),
          ),
      ],
    ),
  );
}

/// The two images the area offers: the word of their file names, the title
/// above their buttons and the name in the share window.
enum _InviteImage {
  qr('qr', 'QR Code', 'QR Code'),
  poster('poster', 'Pôster A4', 'pôster');

  const _InviteImage(this.file, this.title, this.label);
  final String file, title, label;
}

/// Where an image goes: the "Save as" window or the share window.
enum _Export {
  save('Baixar', Icons.download_rounded),
  share('Compartilhar', Icons.share_rounded);

  const _Export(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _PosterPainter extends CustomPainter {
  const _PosterPainter(this.poster);
  final InvitePoster poster;

  @override
  void paint(Canvas canvas, Size size) => poster.paint(canvas, size);

  @override
  bool shouldRepaint(_PosterPainter old) =>
      old.poster.petshop != poster.petshop || old.poster.qr != poster.qr;
}
