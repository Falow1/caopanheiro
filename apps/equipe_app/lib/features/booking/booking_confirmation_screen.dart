import 'package:caopanheiro_core/caopanheiro_core.dart' show displayPhone;
import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppContentCard, AppPetIcon, AppTextStyles;

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../core/widgets.dart';
import 'application/create_appointment.dart';
import '../../state/app_scope.dart';
import '../navigation/main_shell.dart';
import 'booking_draft.dart';

class BookingConfirmationScreen extends StatefulWidget {
  const BookingConfirmationScreen({super.key, required this.draft});
  final BookingDraft draft;
  @override
  State<BookingConfirmationScreen> createState() =>
      _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState extends State<BookingConfirmationScreen> {
  BookingDraft get draft => widget.draft;

  Future<void> _confirm(BuildContext context) async {
    final item = createAppointmentFromDraft(draft);
    final controller = AppScope.of(context);
    final saved = await controller.saveAppointment(item);
    if (!saved && context.mounted && controller.serviceQuoteChange != null) {
      await _reviewChange(context, controller.serviceQuoteChange!);
    }
    if (saved && context.mounted) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(
            Icons.check_circle_rounded,
            color: AppColors.primary,
            size: 54,
          ),
          title: const Text('Agendamento confirmado'),
          content: Text(
            '${item.petNames} · ${date(item.displayStartsAt)} às ${time(item.displayStartsAt)}',
            textAlign: TextAlign.center,
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const MainShell()),
                (_) => false,
              ),
              child: const Text('Voltar à agenda'),
            ),
          ],
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
        final previous = draft.services[petId]!.firstWhere(
          (value) => value.id == service['id'],
        );
        final nextPrice = (service['priceCents'] as num) / 100;
        if (previous.price != nextPrice ||
            previous.duration != service['durationMinutes']) {
          changes.add(
            '${pet.name} · ${previous.name}\n${money(previous.price)} · ${previous.duration} min → ${money(nextPrice)} · ${service['durationMinutes']} min',
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
            'Total anterior: ${money(draft.price)} · ${draft.duration} min\nNovo total: ${money((quote['priceCents'] as num) / 100)} · ${quote['durationMinutes']} min\n\n${changes.join('\n\n')}\n\nAtualize o resumo e confirme novamente para aceitar.',
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Confirmar agendamento')),
    body: PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '5 de 5 · Confirmação',
            style: AppTextStyles.primaryStrong,
          ),
          const SizedBox(height: 14),
          Text(
            'Revise antes de confirmar',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 22),
          if (draft.editing) ...[
            const Text(
              'Se houver transportes ainda não iniciados, seus horários serão ajustados junto com o atendimento. Endereços e taxas permanecem os mesmos; conflitos impedem a confirmação.',
            ),
            const SizedBox(height: 16),
          ],
          AppContentCard(
            padding: const EdgeInsets.all(19),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  draft.customer.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(displayPhone(draft.customer.phone)),
                const Divider(height: 30),
                Text(
                  '${date(draft.displayStartsAt)} às ${time(draft.displayStartsAt)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text('${draft.duration} minutos estimados'),
                const Divider(height: 30),
                ...draft.pets.map(
                  (pet) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            AppPetIcon(icon: pet.breedIcon, size: 30),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                pet.name,
                                style: AppTextStyles.emphasis,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          draft.services[pet.id]!
                              .map((service) => service.name)
                              .join(' · '),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Valor total', style: AppTextStyles.strong),
                    Text(
                      money(draft.price),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          TextFormField(
            initialValue: draft.notes,
            maxLines: 3,
            maxLength: 2000,
            enabled:
                !AppScope.of(context).busy &&
                !AppScope.of(context).catalogOffline,
            decoration: const InputDecoration(
              labelText: 'Orientações para o profissional',
              helperText: 'Aplicam-se a todos os pets deste agendamento.',
            ),
            onChanged: (value) => draft.notes = value,
          ),
          const SizedBox(height: 16),
          if (AppScope.of(context).error != null)
            Text(AppScope.of(context).error!),
          FilledButton(
            onPressed:
                (AppScope.of(context).busy ||
                    AppScope.of(context).catalogOffline)
                ? null
                : () => _confirm(context),
            child: Text(
              AppScope.of(context).busy
                  ? 'Confirmando...'
                  : 'Confirmar agendamento',
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Voltar e editar'),
          ),
        ],
      ),
    ),
  );
}
