import 'all_companies_shell.dart';
import '../auth/company_selection_screen.dart';
import '../more/confirm_sign_out.dart';
import 'package:flutter/material.dart';

import 'billing_notice.dart';
import '../../domain/models.dart';
import '../../state/workforce_scope.dart';
import '../../modules/professional/features/navigation/main_shell.dart' as pro;
import '../../modules/driver/features/navigation/main_shell.dart' as driver;
import '../auth/login_screen.dart';
import 'main_shell.dart';

class UnifiedShell extends StatefulWidget {
  const UnifiedShell({super.key});
  @override
  State<UnifiedShell> createState() => _UnifiedShellState();
}

class _UnifiedShellState extends State<UnifiedShell> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = WorkforceScope.of(context);
    if (scope.function == null &&
        !scope.busy &&
        scope.error == null &&
        scope.functions.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && scope.function == null && !scope.busy) {
          scope.selectFunction(scope.functions.first);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = WorkforceScope.of(context);
    if (scope.team.user == null &&
        scope.team.company == null &&
        scope.team.companies.isEmpty &&
        !scope.busy) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (_) => false,
          );
        }
      });
      return const SizedBox.shrink();
    }
    if (scope.function != null) {
      // Expired plan notice (E2) over every function of the team.
      return BillingNoticeHost(
        child: scope.allCompanies
            ? const AllCompaniesShell()
            : switch (scope.function!) {
                TenantRole.professional => const pro.MainShell(),
                TenantRole.driver => const driver.MainShell(),
                _ => const MainShell(),
              },
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (scope.busy) const CircularProgressIndicator(),
                if (scope.error != null) Text(scope.error!),
                if (!scope.busy) ...[
                  if (scope.error != null && scope.team.companies.isNotEmpty)
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => const CompanySelectionScreen(),
                        ),
                      ),
                      child: const Text('Escolher empresa'),
                    ),

                  for (final role in scope.functions)
                    ListTile(
                      title: Text(role.label),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => scope.selectFunction(role),
                    ),
                  TextButton(
                    onPressed: () => confirmSignOut(context),
                    child: const Text('Sair'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
