import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppScreenTips, AppTourTarget;
import '../../core/screen_tips.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppTextStyles, AppConfirmTone, showAppConfirmation;

import '../../domain/policies/tutor_invite_link.dart';

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../core/widgets.dart';
import '../../state/app_scope.dart';
import '../agenda/appointment_detail_screen.dart';
import '../booking/pet_selection_screen.dart';
import '../pets/pet_form_screen.dart';
import 'customer_form_screen.dart';

class CustomerDetailScreen extends StatelessWidget {
  const CustomerDetailScreen({super.key, required this.customerId});
  final String customerId;

  @override
  Widget build(BuildContext context) => AppScreenTips(
    screen: TipScreens.customer,
    tips: TeamTips.customer,
    child: _content(context),
  );

  Widget _content(BuildContext context) {
    final controller = AppScope.of(context);
    if (controller.user == null) return const SizedBox.shrink();
    final matches = controller.customers.where((item) => item.id == customerId);
    if (matches.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text('Cadastro indisponível. Atualize os clientes.'),
        ),
      );
    }
    final customer = matches.first;
    final appointments = controller.appointments
        .where(
          (item) =>
              item.customer.id == customerId &&
              item.startsAt.isAfter(
                controller.catalogOnly ? DateTime.now() : DateTime(2026, 9, 17),
              ),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text('Detalhes do tutor')),
      body: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 31,
                  backgroundColor: AppColors.mint,
                  child: Text(
                    customer.name.substring(0, 1),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(customer.phone),
                      Text(customer.email),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (!controller.catalogOffline &&
                controller.user!.canManage('CUSTOMERS'))
              AppTourTarget(
                id: TipTargets.customerEdit,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CustomerFormScreen(customer: customer),
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar tutor'),
                ),
              ),
            if (customer.tutorUid != null &&
                controller.user?.canManagePeople == true)
              OutlinedButton.icon(
                onPressed: controller.busy || controller.readOnly
                    ? null
                    : () async {
                        final company = controller.company;
                        final confirmed = await showAppConfirmation(
                          context,
                          title: 'Desvincular cliente?',
                          message:
                              'Cliente: ${customer.name}\nPetshop: ${company?.name ?? ''}\n\nA conta do tutor perderá o acesso somente a este petshop. Cadastro, pets, histórico, conta e outros vínculos serão preservados. Para voltar, será necessário outro convite, ou o gestor principal aprovar o pedido feito pelo link do petshop.',
                          confirmLabel: 'Desvincular',
                          tone: AppConfirmTone.danger,
                        );
                        if (!context.mounted ||
                            !confirmed ||
                            controller.company?.id != company?.id) {
                          return;
                        }
                        final ok = await controller.unlinkCustomerAccount(
                          customer.id,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ok
                                    ? 'Conta do tutor desvinculada deste petshop.'
                                    : controller.error ??
                                          'Não foi possível desvincular.',
                              ),
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.link_off),
                label: const Text('Desvincular cliente'),
              ),
            if (controller.catalogOnly) ...[
              const SizedBox(height: 12),
              Text(
                customer.tutorUid == null
                    ? 'Ainda sem vínculo com uma conta de tutor.'
                    : 'Conta de tutor vinculada a este cadastro.',
              ),
              if (customer.tutorUid == null &&
                  !controller.catalogOffline &&
                  controller.user!.canManage('CUSTOMERS') &&
                  !controller.entitlements.tutorApp)
                const Text(
                  'O convite ao app do tutor fica nos planos Essencial e Completo. No Grátis, a equipe agenda pelo cliente.',
                  style: AppTextStyles.captionMuted,
                ),
              if (customer.tutorUid == null &&
                  !controller.catalogOffline &&
                  controller.user!.canManage('CUSTOMERS') &&
                  controller.entitlements.tutorApp)
                OutlinedButton(
                  onPressed: controller.busy
                      ? null
                      : () async {
                          final code = await controller.createTutorLink(
                            customer.id,
                          );
                          if (code == null || !context.mounted) return;
                          await showDialog<void>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('Vincular conta do tutor'),
                              content: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tutorInviteLink(code) == null
                                          ? 'Entregue este código ao tutor de ${customer.email}. Ele deve confirmar o e-mail da conta e aceitar o vínculo no aplicativo. O código vale por 24 horas; gerar outro invalida o anterior.'
                                          : 'Envie este link ao tutor de ${customer.email}. Ao abrir, ele entra ou cria a conta com esse e-mail, confirma o e-mail e aceita o vínculo. O convite vale por 24 horas; gerar outro invalida o anterior.',
                                    ),
                                    if (tutorInviteLink(code) != null) ...[
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Link de convite',
                                        style: AppTextStyles.captionMuted,
                                      ),
                                      SelectableText(tutorInviteLink(code)!),
                                      const SizedBox(height: 6),
                                      OutlinedButton.icon(
                                        onPressed: () => _copy(
                                          dialogContext,
                                          tutorInviteLink(code)!,
                                          'Link copiado.',
                                        ),
                                        icon: const Icon(Icons.link_rounded),
                                        label: const Text('Copiar link'),
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Código de vínculo',
                                      style: AppTextStyles.captionMuted,
                                    ),
                                    SelectableText(code),
                                    const SizedBox(height: 6),
                                    OutlinedButton.icon(
                                      onPressed: () => _copy(
                                        dialogContext,
                                        code,
                                        'Código copiado.',
                                      ),
                                      icon: const Icon(Icons.copy_rounded),
                                      label: const Text('Copiar código'),
                                    ),
                                  ],
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  child: const Text('Fechar'),
                                ),
                              ],
                            ),
                          );
                        },
                  child: const Text('Gerar código de vínculo'),
                ),
              if (controller.error != null) Text(controller.error!),
            ],
            const SizedBox(height: 28),
            SectionTitle(
              'Pets',
              action:
                  controller.catalogOffline ||
                      !controller.user!.canManage('CUSTOMERS')
                  ? null
                  : 'Adicionar pet',
              onAction:
                  controller.catalogOffline ||
                      !controller.user!.canManage('CUSTOMERS')
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PetFormScreen(customerId: customer.id),
                      ),
                    ),
            ),
            ...customer.pets.map(
              (pet) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: ListTile(
                    onTap:
                        controller.catalogOffline ||
                            !controller.user!.canManage('CUSTOMERS')
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PetFormScreen(
                                customerId: customer.id,
                                pet: pet,
                              ),
                            ),
                          ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 7,
                    ),
                    leading: Text(
                      pet.emoji,
                      style: const TextStyle(fontSize: 30),
                    ),
                    title: Text(
                      pet.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    subtitle: Text('${pet.species} · ${pet.breed}'),
                    trailing: const Icon(Icons.edit_outlined, size: 20),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const SectionTitle('Próximos agendamentos'),
            if (appointments.isEmpty)
              const Text('Nenhum agendamento futuro.')
            else
              ...appointments.map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AppointmentDetailScreen(appointmentId: item.id),
                    ),
                  ),
                  title: Text(item.petNames, style: AppTextStyles.strong),
                  subtitle: Text(
                    '${date(item.displayStartsAt)} às ${time(item.displayStartsAt)}',
                  ),
                  trailing: StatusBadge(status: item.status),
                ),
              ),
            const SizedBox(height: 24),
            if (!controller.catalogOffline &&
                controller.user!.canManage('APPOINTMENTS'))
              AppTourTarget(
                id: TipTargets.customerNew,
                child: FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PetSelectionScreen(customer: customer),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Novo agendamento'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> _copy(
  BuildContext context,
  String value,
  String confirmation,
) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(confirmation)));
}
