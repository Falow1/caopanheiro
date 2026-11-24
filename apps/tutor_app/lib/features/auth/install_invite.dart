import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppColors, AppRadii;
import 'package:flutter/material.dart';

import 'install_support.dart';

/// The small invitation of the phone login to install the Tutor.
///
/// On Android, Instalar opens Chrome's own install window; the steps of the
/// browser menu are only the last resort, when Chrome has none to offer. On
/// the iPhone, Safari does not install from a page, so the steps show.
class InstallInvite extends StatelessWidget {
  const InstallInvite({super.key, required this.support, required this.onDone});

  final InstallSupport support;

  /// Installed or closed: the login stops showing the invitation.
  final VoidCallback onDone;

  Future<void> _install(BuildContext context) async {
    if (support.device == InstallDevice.android) {
      switch (await support.prompt()) {
        case InstallResult.accepted:
          onDone();
          return;
        case InstallResult.dismissed:
          // The tutor said no in Chrome's window; the invitation stays.
          return;
        case InstallResult.unavailable:
          break;
      }
    }
    if (context.mounted) await showInstallSteps(context, support.device);
  }

  void _close() {
    support.close();
    onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('login.install'),
      padding: const EdgeInsets.fromLTRB(16, 4, 2, 4),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.mint, AppColors.paper]),
        borderRadius: AppRadii.r16,
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Instale o Cãopanheiro',
                    style: TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(text: '\nno seu celular'),
                ],
              ),
              style: TextStyle(color: AppColors.ink, fontSize: 14, height: 1.3),
            ),
          ),
          const SizedBox(width: 6),
          FilledButton(
            onPressed: () => _install(context),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: const StadiumBorder(),
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
            child: const Text('Instalar'),
          ),
          IconButton(
            tooltip: 'Agora não',
            onPressed: _close,
            icon: const Icon(
              Icons.close_rounded,
              size: 20,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// The steps of the browser menu, in a sheet from the bottom.
Future<void> showInstallSteps(BuildContext context, InstallDevice device) {
  final iphone = device == InstallDevice.iphone;
  final steps = iphone
      ? const [
          (
            Icons.ios_share_rounded,
            'Toque em Compartilhar',
            'No Safari, o quadrado com a seta. Se não estiver à vista, toque antes nos três pontos ao lado do endereço.',
          ),
          (
            Icons.add_box_outlined,
            'Escolha Adicionar à Tela de Início',
            'Se não aparecer, role a lista para baixo.',
          ),
          (
            Icons.check_circle_outline_rounded,
            'Toque em Adicionar',
            'O Cãopanheiro aparece na tela inicial, com a pata.',
          ),
        ]
      : const [
          (
            Icons.more_vert_rounded,
            'Toque nos três pontos',
            'No Chrome, no canto de cima, ao lado do endereço.',
          ),
          (
            Icons.install_mobile_rounded,
            'Escolha Instalar app',
            'Em alguns celulares, aparece como Adicionar à tela inicial.',
          ),
          (
            Icons.check_circle_outline_rounded,
            'Toque em Instalar',
            'O Cãopanheiro aparece na tela inicial, com a pata.',
          ),
        ];
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              iphone ? 'Instalar no iPhone' : 'Instalar no Android',
              style: Theme.of(sheet).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            for (final (index, (icon, title, detail)) in steps.indexed) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: AppColors.mint,
                      borderRadius: AppRadii.r12,
                    ),
                    child: Icon(icon, color: AppColors.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${index + 1}. $title',
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          detail,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 4),
            FilledButton(
              onPressed: () => Navigator.pop(sheet),
              child: const Text('Entendi'),
            ),
          ],
        ),
      ),
    ),
  );
}
