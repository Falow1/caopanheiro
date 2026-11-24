import 'package:caopanheiro_contracts/caopanheiro_contracts.dart'
    show TenantRole;
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppColors, AppRadii;
import 'package:flutter/material.dart';
import '../../state/workforce_scope.dart';
import '../navigation/unified_shell.dart';
import '../navigation/company_data_dropdown.dart';

class WorkforceActions extends StatelessWidget {
  const WorkforceActions({super.key, this.showCurrentSelection = true});
  final bool showCurrentSelection;
  @override
  Widget build(BuildContext context) {
    final scope = WorkforceScope.maybeOf(context);
    if (scope == null) return const SizedBox.shrink();
    final actions = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (scope.hasUnconfirmed)
          const Text(
            'Confirme a operação pendente ou atualize antes de trocar de função ou petshop.',
          ),
        if (scope.functions.length > 1)
          ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: const Text('Trocar função'),
            subtitle: showCurrentSelection
                ? Text(scope.function?.label ?? '')
                : null,
            trailing: showCurrentSelection
                ? null
                : const Icon(Icons.chevron_right),
            onTap: scope.busy || scope.hasUnconfirmed
                ? null
                : () async {
                    final role = await showDialog(
                      context: context,
                      builder: (_) => _FunctionDialog(
                        functions: scope.functions,
                        current: scope.function,
                      ),
                    );
                    if (role == null ||
                        !context.mounted ||
                        role == scope.function) {
                      return;
                    }
                    Navigator.of(context).popUntil((route) => route.isFirst);
                    // The old module must be unmounted before clearing its view.
                    final switching = scope.selectFunction(role);
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const UnifiedShell()),
                      (_) => false,
                    );
                    await switching;
                  },
          ),
        const CompanyDataDropdown(),
      ],
    );
    return showCurrentSelection ? actions : Card(child: actions);
  }
}

class _FunctionDialog extends StatelessWidget {
  const _FunctionDialog({required this.functions, required this.current});
  final List<TenantRole> functions;
  final TenantRole? current;

  @override
  Widget build(BuildContext context) {
    final columns = MediaQuery.textScalerOf(context).scale(15) > 20 ? 1 : 2;
    return AlertDialog(
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.r12),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      actionsPadding: const EdgeInsets.all(20),
      scrollable: true,
      title: const Text('Trocar função'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < functions.length; index += columns) ...[
              if (index > 0) const SizedBox(height: 12),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var offset = 0; offset < columns; offset++) ...[
                      if (offset > 0) const SizedBox(width: 12),
                      Expanded(
                        child: index + offset < functions.length
                            ? _option(
                                context,
                                functions[index + offset],
                                horizontal: columns == 1,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Voltar'),
          ),
        ),
      ],
    );
  }

  Widget _option(
    BuildContext context,
    TenantRole role, {
    required bool horizontal,
  }) => Semantics(
    selected: role == current,
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: Size(
          0,
          horizontal
              ? 64
              : 64 + MediaQuery.textScalerOf(context).scale(15) * 2.8,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.r12),
        backgroundColor: role == current ? AppColors.mint : AppColors.paper,
        side: BorderSide(
          color: role == current ? AppColors.primary : AppColors.line,
        ),
      ),
      onPressed: () => Navigator.of(context).pop(role),
      child: horizontal
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_icon(role)),
                const SizedBox(width: 12),
                Flexible(child: Text(role.label, textAlign: TextAlign.center)),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_icon(role)),
                const SizedBox(height: 8),
                Text(role.label, textAlign: TextAlign.center),
              ],
            ),
    ),
  );

  IconData _icon(TenantRole role) => switch (role) {
    TenantRole.manager => Icons.manage_accounts_outlined,
    TenantRole.attendant => Icons.support_agent_outlined,
    TenantRole.professional => Icons.content_cut_outlined,
    TenantRole.driver => Icons.local_shipping_outlined,
  };
}
