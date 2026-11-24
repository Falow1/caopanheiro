import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppConfirmTone, showAppConfirmation;
import '../../state/app_scope.dart';

Future<bool> unlinkStaffFromPetshop(
  BuildContext context, {
  required String name,
  required Map<String, dynamic> target,
}) async {
  final c = AppScope.of(context);
  final company = c.company;
  if (c.busy ||
      c.readOnly ||
      c.user?.canManagePeople != true ||
      company == null) {
    return false;
  }
  final confirmed = await showAppConfirmation(
    context,
    title: 'Desvincular do petshop?',
    message:
        'Pessoa: $name\nPetshop: ${company.name}\n\nA pessoa perderá o acesso somente a este petshop. Sua conta, os outros vínculos e o histórico serão preservados. Atendimentos e entregas em andamento precisam ser concluídos ou reatribuídos.',
    confirmLabel: 'Desvincular',
    tone: AppConfirmTone.danger,
  );
  if (!context.mounted || !confirmed || c.company?.id != company.id) {
    return false;
  }
  final success = await c.unlinkWorkforceMember(target);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Vínculo com este petshop removido.'
              : c.error ?? 'Não foi possível desvincular.',
        ),
      ),
    );
  }
  return success;
}

