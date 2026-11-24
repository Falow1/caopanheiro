export '../../../core/team_layout.dart';

import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show
        AppBrand,
        AppDimensions,
        AppNoticeBanner,
        AppPageBody,
        AppSectionHeader,
        AppSpacing;

import 'app_theme.dart';

export '../features/transports/widgets/transport_status_chip.dart'
    show TransportStatusChip;
export '../features/transports/widgets/transport_card.dart' show TransportCard;
export '../features/transports/widgets/address_card.dart' show AddressCard;
export '../features/transports/widgets/transport_primary_action.dart'
    show TransportPrimaryAction;
export '../features/transports/widgets/empty_transport_state.dart'
    show EmptyTransportState;

class Brand extends StatelessWidget {
  const Brand({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) => AppBrand.driver(compact: compact);
}

class PageBody extends StatelessWidget {
  const PageBody({
    super.key,
    required this.child,
    this.padding = AppSpacing.page,
  });
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => AppPageBody(
    padding: padding,
    maxWidth: AppDimensions.teamPageWidth,
    child: child,
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action});
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) =>
      AppSectionHeader(title: title, action: action);
}

class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({super.key, required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => AppNoticeBanner(
    background: AppColors.noticeSurface,
    icon: Icons.cloud_off_outlined,
    iconColor: AppColors.warning,
    title: 'Sem conexão com o servidor',
    message: 'Os dados carregados continuam visíveis.',
    action: TextButton(
      onPressed: onRetry,
      child: const Text('Tentar novamente'),
    ),
  );
}
