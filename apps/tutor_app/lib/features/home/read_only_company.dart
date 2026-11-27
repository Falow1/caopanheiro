import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppTextStyles;
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/policies/contact_input.dart' show displayPhone;
import '../../state/app_scope.dart';

const readOnlyTitle = 'Indisponível no app no momento';
const bookingPausedTitle = 'Agendamento pelo app indisponível no momento';

/// The selected petshop is not taking bookings through the app (A1-u): the
/// tutor still reads pets and appointments, and talks to the petshop for the
/// rest. The reason (plan or payment) is never shown.
class ReadOnlyCompanyBanner extends StatelessWidget {
  const ReadOnlyCompanyBanner({super.key, this.bottom = 20});
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    if (controller.companyBookingPaused) {
      return _BookingNotice(
        bottom: bottom,
        title: bookingPausedTitle,
        text: _byPhone(controller.companyContactPhone),
      );
    }
    final from = controller.companyBookingNoticeFrom;
    if (!controller.companyReadOnly && from != null) {
      return _BookingNotice(
        bottom: bottom,
        text:
            'Este petshop pode deixar de receber agendamentos pelo app a partir de ${formatShortDate(from)}.',
      );
    }
    if (!controller.companyReadOnly) return const SizedBox.shrink();
    final phone = controller.companyContactPhone;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.pendingSurface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded, color: AppColors.pendingInk),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    readOnlyTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.pendingInk,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Você pode consultar seus pets e agendamentos.',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    phone.isEmpty
                        ? 'Para agendar ou mudar algo, fale com o petshop.'
                        : 'Para agendar ou mudar algo, fale com o petshop: $phone',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _byPhone(String phone) => phone.isEmpty
    ? 'Para agendar ou remarcar, fale com o petshop.'
    : 'Para agendar ou remarcar, fale com o petshop: ${displayPhone(phone)}';

/// DD/MM, without the year: the notice is about the next days.
String formatShortDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}';

/// Discreet notice about bookings in the app (E2). It never says why.
class _BookingNotice extends StatelessWidget {
  const _BookingNotice({required this.bottom, required this.text, this.title});
  final double bottom;
  final String? title;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: bottom),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: title == null ? AppColors.cream : AppColors.pendingSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: title == null ? AppColors.muted : AppColors.pendingInk,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.pendingInk,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(text, style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Said instead of opening a booking or a rescheduling while they go by
/// phone (E2).
Future<void> showBookingByPhone(BuildContext context) {
  final phone = AppScope.of(context).companyContactPhone;
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text(bookingPausedTitle),
      content: Text(_byPhone(phone)),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Entendi'),
        ),
      ],
    ),
  );
}

/// Said instead of opening a booking or a change in a read-only petshop.
Future<void> showReadOnlyCompany(BuildContext context) {
  final phone = AppScope.of(context).companyContactPhone;
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text(readOnlyTitle),
      content: Text(
        phone.isEmpty
            ? 'Para agendar ou mudar algo, fale com o petshop.'
            : 'Para agendar ou mudar algo, fale com o petshop: $phone',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Entendi'),
        ),
      ],
    ),
  );
}
