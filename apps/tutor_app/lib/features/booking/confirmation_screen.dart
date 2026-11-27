import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppScreenTips, AppTourTarget;
import '../../core/screen_tips.dart';
import 'package:flutter/services.dart' show MaxLengthEnforcement;
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppContentCard, AppPetIcon, AppStatusBadge, AppTextStyles;

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/text_limits.dart';
import 'application/create_appointment.dart';
import '../../state/app_scope.dart';
import '../navigation/tutor_shell_scope.dart';
import '../navigation/tutor_wide_layout.dart';
import '../../domain/repositories/tutor_session.dart' show Distribution;
import 'booking_draft.dart';
import 'success_screen.dart';
import 'widgets/booking_frame.dart';

class ConfirmationScreen extends StatefulWidget {
  const ConfirmationScreen({super.key, required this.draft});
  final BookingDraft draft;
  @override
  State<ConfirmationScreen> createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends State<ConfirmationScreen> {
  BookingDraft get draft => widget.draft;
  late final TextEditingController _tutorNotes = TextEditingController(
    text: draft.tutorNotes,
  )..addListener(() => draft.tutorNotes = _tutorNotes.text);

  @override
  void dispose() {
    _tutorNotes.dispose();
    super.dispose();
  }

  Future<void> _confirm(BuildContext context) async {
    final appointment = createAppointmentFromDraft(draft);
    final controller = AppScope.of(context);
    final saved = await controller.createAppointment(appointment);
    if (!saved && context.mounted && controller.serviceQuoteChange != null) {
      await _reviewChange(context, controller.serviceQuoteChange!);
    }
    if (saved && context.mounted && draft.reschedule) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Agendamento remarcado.')));
      // Back to the appointment: review and schedule screens are closed.
      Navigator.of(context)
        ..pop()
        ..pop();
      return;
    }
    if (saved && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          settings: bookingDoneRoute,
          builder: (_) => SuccessScreen(
            appointment:
                AppScope.of(context).lastConfirmedAppointment ?? appointment,
          ),
        ),
      );
    }
  }

  Future<void> _reviewChange(
    BuildContext context,
    Map<String, dynamic> quote,
  ) async {
    final changes = <String>[];
    for (final rawItem in quote['items'] as List) {
      final item = Map<String, dynamic>.from(rawItem as Map);
      final petId = item['petId'] as String;
      final pet = draft.pets.firstWhere((pet) => pet.id == petId);
      for (final rawService in item['services'] as List) {
        final service = Map<String, dynamic>.from(rawService as Map);
        final previous = draft.selectedServices[petId]!.firstWhere(
          (value) => value.id == service['id'],
        );
        final nextPrice = (service['priceCents'] as num) / 100;
        if (previous.price != nextPrice ||
            previous.durationMinutes != service['durationMinutes']) {
          changes.add(
            '${pet.name} · ${previous.name}\n${formatMoney(previous.price)} · ${previous.durationMinutes} min → ${formatMoney(nextPrice)} · ${service['durationMinutes']} min',
          );
        }
      }
    }
    final update = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Revise os serviços atualizados'),
        content: SingleChildScrollView(
          child: Text(
            'Total anterior: ${formatMoney(draft.totalPrice)} · ${draft.totalDuration} min\nNovo total: ${formatMoney((quote['priceCents'] as num) / 100)} · ${quote['durationMinutes']} min\n\n${changes.join('\n\n')}\n\nAtualize o resumo e confirme novamente para aceitar.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Atualizar resumo'),
          ),
        ],
      ),
    );
    if (update == true && mounted) {
      setState(() => draft.applyServiceQuote(quote));
    }
  }

  @override
  Widget build(BuildContext context) => AppScreenTips(
    screen: TipScreens.bookingConfirm,
    tips: tutorTips(context, TutorTips.bookingConfirm),
    child: _content(context),
  );

  bool get _concurrent =>
      draft.scheduleMinutes != null &&
      draft.scheduleMinutes != draft.totalDuration;

  Widget _content(BuildContext context) {
    final controller = AppScope.of(context);
    final at = draft.companyStartsAt ?? draft.startsAt;
    final quote = draft.transportQuote;
    final steps = bookingStepCount(context, reschedule: draft.reschedule);
    // The summary at the right already shows the pets, the date and the
    // values: the card below would repeat it.
    final side = tutorTwoColumns(context);
    return BookingFrame(
      title: draft.reschedule ? 'Revisar remarcação' : 'Revisar agendamento',
      step: steps - 1,
      stepCount: steps,
      phoneBottom: 30,
      // Beside the steps the summary takes the place of the card, and its tip.
      summaryTip: TipTargets.confirmSummary,
      summary: BookingSummary(
        pets: draft.pets,
        services: draft.selectedServices,
        when: at == null ? null : BookingSummary.day(at, formatTime(at)),
        professional: draft.professionalLabel,
        showProfessional: controller.integrated,
        petProfessionals: controller.integrated && draft.pets.length > 1
            ? draft.petProfessionals
            : null,
        reservedMinutes: draft.scheduleMinutes,
        transport: quote == null ? null : BookingSummary.transportLine(quote),
        transportCents: quote == null
            ? 0
            : (quote['totalCents'] as num).toInt(),
      ),
      primary: FilledButton(
        onPressed: controller.busy ? null : () => _confirm(context),
        child: Text(
          controller.busy
              ? 'Confirmando...'
              : draft.reschedule
              ? 'Confirmar remarcação'
              : 'Confirmar agendamento',
        ),
      ),
      primaryTip: TipTargets.confirmButton,
      back: TextButton(
        onPressed: controller.busy ? null : () => Navigator.pop(context),
        child: const Text('Voltar e editar'),
      ),
      barBack: true,
      children: [
        Text(
          'Está tudo certo?',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          draft.reschedule
              ? 'Confira a nova data antes de confirmar. O horário atual só é liberado depois da confirmação.'
              : 'Confira os detalhes antes de confirmar.',
        ),
        const SizedBox(height: 24),
        if (!side) ...[
          AppTourTarget(
            id: TipTargets.confirmSummary,
            child: AppContentCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SummaryLine(
                    icon: Icons.calendar_today_outlined,
                    label: 'Data e horário',
                    value: formatDateTime(
                      draft.companyStartsAt ?? draft.startsAt!,
                    ),
                  ),
                  if (AppScope.of(context).integrated) ...[
                    const SizedBox(height: 16),
                    _SummaryLine(
                      icon: Icons.person_outline_rounded,
                      label: 'Profissional',
                      value: draft.distribution == Distribution.any
                          ? 'Qualquer profissional disponível'
                          : draft.professionalLabel,
                    ),
                  ],
                  const Divider(height: 32),
                  ...draft.pets.map(
                    (pet) => Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppPetIcon(icon: pet.breedIcon, size: 40),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pet.name,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  draft.selectedServices[pet.id]!
                                      .map((service) => service.name)
                                      .join(' · '),
                                ),
                                if (draft.pets.length > 1 &&
                                    AppScope.of(context).integrated)
                                  if (draft.petProfessionals[pet.id]
                                      case final line?)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Text(
                                        draft.distribution == Distribution.any
                                            ? 'Previsto: $line'
                                            : line,
                                        style: AppTextStyles.strong,
                                      ),
                                    ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 20),
                  _SummaryLine(
                    icon: Icons.schedule_rounded,
                    label: _concurrent
                        ? 'Duração somada dos serviços'
                        : 'Tempo estimado',
                    value: '${draft.totalDuration} minutos',
                  ),
                  // Pets with different professionals are done at the same time.
                  if (_concurrent) ...[
                    const SizedBox(height: 16),
                    _SummaryLine(
                      icon: Icons.timelapse_rounded,
                      label: 'Tempo previsto da reserva',
                      value: '${draft.scheduleMinutes} minutos',
                    ),
                  ],
                  const SizedBox(height: 16),
                  _SummaryLine(
                    icon: Icons.payments_outlined,
                    label: 'Total dos serviços',
                    value: formatMoney(draft.totalPrice),
                    emphasize: true,
                  ),
                  const SizedBox(height: 12),
                  // Payment to the petshop in the app (P3) is announced
                  // until the payment provider exists (E2).
                  const Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Pagamento no petshop. Pix, cartão e boleto pelo app em breve.',
                          style: AppTextStyles.caption,
                        ),
                      ),
                      SizedBox(width: 8),
                      AppStatusBadge(
                        label: 'Em breve',
                        background: AppColors.inactiveSurface,
                        foreground: AppColors.inactiveInk,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (draft.transportQuote != null) ...[
          AppContentCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Transporte solicitado · sujeito à confirmação da equipe',
                ),
                for (final leg in draft.transportQuote!['legs'] as List)
                  Text(
                    '${leg['type'] == 'PICKUP' ? 'Coleta' : 'Retorno'} · ${formatKm(leg['meters'] as num)} · ${formatMoney(leg['feeCents'] / 100)}',
                  ),
                // The fee and the total are in the summary at the right.
                if (!side) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Taxa de transporte: ${formatMoney(draft.transportQuote!["totalCents"] / 100)}',
                  ),
                  Text(
                    'Total com serviços: ${formatMoney(draft.totalPrice + draft.transportQuote!["totalCents"] / 100)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (!draft.reschedule) ...[
          _PaymentDemo(
            selected: draft.paymentMethod,
            enabled: !controller.busy,
            onSelected: (method) =>
                setState(() => draft.paymentMethod = method),
          ),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: _tutorNotes,
          enabled: !controller.busy,
          minLines: 2,
          maxLines: 4,
          maxLength: maxTutorNotesLength,
          // The server counts UTF-16 units; the formatter and the
          // counter follow it instead of counting visible characters.
          maxLengthEnforcement: MaxLengthEnforcement.none,
          inputFormatters: const [ServerLengthFormatter(maxTutorNotesLength)],
          buildCounter:
              (
                context, {
                required currentLength,
                required maxLength,
                required isFocused,
              }) => Text(
                '${serverTextLength(_tutorNotes.text)}/$maxLength',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Orientações para a equipe (opcional)',
            hintText: 'Ex.: tem medo de secador, prefere tosa mais curta',
            helperText: 'A equipe verá este recado junto com o agendamento.',
            helperMaxLines: 2,
          ),
        ),
        if (controller.error != null) ...[
          const SizedBox(height: 12),
          Text(
            controller.error!,
            style: const TextStyle(color: AppColors.danger),
          ),
        ],
      ],
    );
  }
}

/// How the tutor intends to pay. Demonstration only: nothing is charged and
/// the choice stays in this phone.
const paymentDemoMethods = [
  ('PIX', 'Pix', 'QR Code do Pix no petshop ou na entrega'),
  ('CASH', 'Dinheiro', 'No petshop ou na entrega do pet'),
  (
    'CARD_MACHINE',
    'Máquina móvel',
    'Cartão na maquininha, no petshop ou na entrega',
  ),
  ('APP', 'Pagar pelo app', 'Cartão ou Pix pelo aplicativo'),
];

class _PaymentDemo extends StatelessWidget {
  const _PaymentDemo({
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });
  final String? selected;
  final bool enabled;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Pagamento', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 4),
      const Text(
        'Escolha como prefere pagar no dia do atendimento.',
        style: AppTextStyles.captionMuted,
      ),
      const SizedBox(height: 12),
      BookingGrid(
        sameHeight: true,
        children: [
          for (final (id, title, subtitle) in paymentDemoMethods)
            BookingCheckCard(
              key: ValueKey('payment-$id'),
              title: title,
              subtitle: subtitle,
              selected: selected == id,
              onTap: enabled ? () => onSelected(id) : null,
            ),
        ],
      ),
      AppContentCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                selected == 'APP'
                    ? 'Versão de demonstração: o pagamento pelo app ainda não está disponível e nada será cobrado. Pague no petshop.'
                    : 'Versão de demonstração: nenhum valor é cobrado agora e a escolha ainda não é enviada ao petshop. Combine o pagamento com a equipe.',
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.icon,
    required this.label,
    required this.value,
    this.emphasize = false,
  });
  final IconData icon;
  final String label;
  final String value;
  final bool emphasize;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: AppColors.primary, size: 21),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.captionMuted),
            const SizedBox(height: 2),
            Text(
              value,
              style: emphasize
                  ? Theme.of(context).textTheme.titleLarge
                  : Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    ],
  );
}
