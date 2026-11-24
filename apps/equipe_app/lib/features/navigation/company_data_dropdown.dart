import 'package:flutter/material.dart';
import '../../state/workforce_scope.dart';

class CompanyDataDropdown extends StatelessWidget {
  const CompanyDataDropdown({super.key});
  static const all = '__all_companies__';
  @override
  Widget build(BuildContext context) {
    final scope = WorkforceScope.of(context);
    if (scope.team.companies.length < 2) return const SizedBox.shrink();
    final value = scope.allCompanies ? all : scope.team.company?.id;
    final names = [
      if (scope.canViewAll) 'Todas as empresas',
      for (final company in scope.team.companies) company.name,
    ];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Empresa dos dados',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: ValueKey('company-data-$value'),
            initialValue: value,
            isExpanded: true,
            itemHeight: null,
            menuMaxHeight: 360,
            decoration: const InputDecoration(),
            // The menu rows keep their vertical padding; the closed field
            // shows the bare name, which that padding would squeeze out.
            selectedItemBuilder: (_) => [
              for (final name in names)
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
            items: [
              if (scope.canViewAll)
                const DropdownMenuItem(
                  value: all,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text('Todas as empresas'),
                  ),
                ),
              for (final company in scope.team.companies)
                DropdownMenuItem(
                  value: company.id,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(company.name),
                  ),
                ),
            ],
            onChanged: scope.busy || scope.hasUnconfirmed
                ? null
                : (choice) async {
                    if (choice == null) return;
                    if (choice == all) {
                      if (!scope.allCompanies) scope.selectAllCompanies();
                      return;
                    }
                    if (!scope.allCompanies &&
                        choice == scope.team.company?.id) {
                      return;
                    }
                    Navigator.of(context).popUntil((route) => route.isFirst);
                    await scope.selectCompany(choice);
                  },
          ),
        ],
      ),
    );
  }
}
