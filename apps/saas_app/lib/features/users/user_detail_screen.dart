import '../onboarding/manager_form_screen.dart';
import 'package:caopanheiro_core/caopanheiro_core.dart' show recordHeading;
import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show
        AppButtonStyles,
        AppConfirmTone,
        AppContentCard,
        AppTextStyles,
        showAppConfirmation;

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../core/widgets.dart';
import '../../state/app_scope.dart';

class UserDetailScreen extends StatelessWidget {
  const UserDetailScreen({
    super.key,
    required this.tenantId,
    required this.userId,
  });
  final String tenantId;
  final String userId;
  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    if (controller.admin == null) return const SizedBox.shrink();
    final tenant = controller.tenantById(tenantId);
    final user = tenant.users.where((item) => item.id == userId).firstOrNull;
    // A deleted account leaves the list after the confirmed refresh.
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Usuário')),
        body: const PageBody(
          child: Text('Este usuário não faz mais parte da lista da empresa.'),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(recordHeading('Usuário', user.recordNumber))),
      body: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ContextHeader(
              tenant: tenant,
              planName: controller.planById(tenant.planId).name,
            ),
            const SizedBox(height: 24),
            Align(
              child: CircleAvatar(
                radius: 38,
                backgroundColor: AppColors.mint,
                child: Text(
                  user.name.substring(0, 1),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              user.name,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            Text(user.role.label, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            AppContentCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _Info('E-mail', user.email),
                  _Info('Situação', user.statusLabel),
                  _Info('Criado em', date(user.createdAt)),
                  _Info(
                    'Último login da conta',
                    user.lastAccess == null
                        ? 'Não disponível'
                        : dateTime(user.lastAccess!),
                    last: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            if (user.deletionPending) ...[
              const Text(
                'A exclusão desta conta foi confirmada e o acesso está bloqueado, mas a remoção da identidade de acesso ainda não foi concluída.',
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                style: AppButtonStyles.dangerOutlined,
                onPressed: controller.busy || controller.readOnly
                    ? null
                    : () => _confirmCompletion(context),
                child: const Text('Concluir exclusão'),
              ),
            ] else if (user.activationPending) ...[
              const Text(
                'O primeiro acesso precisa ser concluído pelo gestor. Para reenviar ou renovar o convite, use Convidar gestor com o mesmo e-mail.',
              ),
              OutlinedButton(
                onPressed: controller.busy || controller.readOnly
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ManagerFormScreen(tenantId: tenantId),
                        ),
                      ),
                child: const Text('Renovar convite'),
              ),
              OutlinedButton(
                onPressed: controller.busy || controller.readOnly
                    ? null
                    : () => _confirm(context, false, user.name),
                child: const Text('Revogar convite'),
              ),
            ] else if (user.active)
              OutlinedButton(
                style: AppButtonStyles.dangerOutlined,
                onPressed: controller.busy
                    ? null
                    : () => _confirm(context, false, user.name),
                child: const Text('Desativar usuário'),
              )
            else
              FilledButton(
                onPressed: controller.busy
                    ? null
                    : () => _confirm(context, true, user.name),
                child: const Text('Reativar usuário'),
              ),
            if (user.principal && !user.activationPending) ...[
              const SizedBox(height: 22),
              const Text(
                'Gestor principal deste petshop. A conta só pode ser excluída pela administração do Cãopanheiro.',
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                style: AppButtonStyles.dangerOutlined,
                onPressed: controller.busy || controller.readOnly
                    ? null
                    : () => _confirmDeletion(
                        context,
                        user.name,
                        tenantIdentification(tenant),
                      ),
                child: const Text('Excluir conta do gestor principal'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirm(BuildContext context, bool active, String name) async {
    final controller = AppScope.of(context);
    final confirmed = await showAppConfirmation(
      context,
      title: active ? 'Reativar $name?' : 'Desativar $name?',
      message: active
          ? 'O usuário voltará a acessar a empresa conforme seu perfil.'
          : 'O usuário perderá acesso, mas o histórico será preservado.',
      confirmLabel: active ? 'Reativar' : 'Desativar',
      tone: active ? AppConfirmTone.neutral : AppConfirmTone.danger,
    );
    if (confirmed) {
      await controller.setUserActive(tenantId, userId, active);
    }
  }

  Future<void> _confirmDeletion(
    BuildContext context,
    String name,
    String company,
  ) => _deleteAccount(
    context,
    title: 'Excluir a conta de $name?',
    message:
        '$name é gestor principal de $company. A conta é excluída por inteiro: a pessoa perde o acesso a todos os aplicativos do Cãopanheiro, inclusive vínculos com outros petshops. '
        'O histórico do petshop é preservado, e o petshop fica sem gestor principal até um novo convite. '
        'A exclusão é recusada se houver tarefa em aberto. Esta ação não pode ser desfeita.',
    action: 'Excluir conta',
  );

  Future<void> _confirmCompletion(BuildContext context) => _deleteAccount(
    context,
    title: 'Concluir a exclusão da conta?',
    message:
        'A exclusão já foi confirmada e o acesso da pessoa está bloqueado. Esta etapa remove a identidade de acesso e não pode ser desfeita.',
    action: 'Concluir exclusão',
  );

  Future<void> _deleteAccount(
    BuildContext context, {
    required String title,
    required String message,
    required String action,
  }) async {
    final controller = AppScope.of(context);
    final navigator = Navigator.of(context);
    final confirmed = await showAppConfirmation(
      context,
      title: title,
      message: message,
      confirmLabel: action,
      tone: AppConfirmTone.danger,
    );
    if (confirmed &&
        await controller.deleteManagerAccount(tenantId, userId) &&
        navigator.mounted) {
      navigator.pop();
    }
  }
}

class _Info extends StatelessWidget {
  const _Info(this.label, this.value, {this.last = false});
  final String label;
  final String value;
  final bool last;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: last ? 0 : 14),
    child: Row(
      children: [
        SizedBox(width: 110, child: Text(label, style: AppTextStyles.metadata)),
        Expanded(child: Text(value, style: AppTextStyles.value)),
      ],
    ),
  );
}
