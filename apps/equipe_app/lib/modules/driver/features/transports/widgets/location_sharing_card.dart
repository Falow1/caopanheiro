import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppContentCard, AppTextStyles;
import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../core/location_sharing.dart';

/// State of the live position on the transport on the way: who sees it, the
/// last position sent and what to do when the phone does not allow it.
class LocationSharingCard extends StatelessWidget {
  const LocationSharingCard({super.key, required this.sharing});
  final DriverLocationSharing sharing;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: sharing,
    builder: (context, _) {
      final sent = sharing.lastSentAt;
      final (icon, title, text, action) = switch (sharing.status) {
        LocationSharingStatus.off => (null, '', '', null),
        LocationSharingStatus.starting => (
          Icons.location_searching,
          'Ligando a localização',
          'Aguarde a primeira posição do celular.',
          null,
        ),
        LocationSharingStatus.sharing => (
          Icons.my_location,
          'Localização ao vivo ligada',
          sent == null
              ? 'Aguardando a primeira posição do celular. O tutor e a equipe veem você no mapa até a entrega.'
              : 'O tutor e a equipe veem você no mapa até a entrega. Última posição enviada às ${time(sent)}.',
          null,
        ),
        LocationSharingStatus.needsPermission => (
          Icons.location_disabled,
          'Localização não permitida',
          'O tutor e a equipe acompanham só as etapas. Permita a localização para eles verem você no mapa.',
          'Permitir localização',
        ),
        LocationSharingStatus.blocked => (
          Icons.location_disabled,
          'Localização bloqueada no celular',
          'Em Configurações, permita a localização do Equipe para o tutor e a equipe verem você no mapa.',
          'Abrir configurações',
        ),
        LocationSharingStatus.serviceOff => (
          Icons.location_off,
          'Localização do celular desligada',
          'Ligue a localização do celular para o tutor e a equipe verem você no mapa.',
          'Ligar localização',
        ),
        LocationSharingStatus.unavailable => (
          Icons.location_off,
          'Sem posição do celular',
          'O GPS parou de responder. Tente de novo; as etapas continuam valendo.',
          'Tentar de novo',
        ),
      };
      if (icon == null) return const SizedBox.shrink();
      return AppContentCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 10),
                Expanded(child: Text(title, style: AppTextStyles.strong)),
              ],
            ),
            const SizedBox(height: 6),
            Text(text),
            if (action != null) ...[
              const SizedBox(height: 10),
              OutlinedButton(onPressed: sharing.retry, child: Text(action)),
            ],
          ],
        ),
      );
    },
  );
}
