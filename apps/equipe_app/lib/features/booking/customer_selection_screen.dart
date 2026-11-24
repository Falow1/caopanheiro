import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppScreenTips, AppTourTarget;
import '../../core/screen_tips.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppDimensions, AppRadii, AppTextStyles;

import '../../core/app_theme.dart';
import '../../core/widgets.dart';
import '../../state/app_scope.dart';
import '../customers/customer_form_screen.dart';
import 'pet_selection_screen.dart';

class CustomerSelectionScreen extends StatefulWidget {
  const CustomerSelectionScreen({super.key});
  @override
  State<CustomerSelectionScreen> createState() =>
      _CustomerSelectionScreenState();
}

class _CustomerSelectionScreenState extends State<CustomerSelectionScreen> {
  String _query = '';
  @override
  Widget build(BuildContext context) => AppScreenTips(
    screen: TipScreens.booking,
    tips: TeamTips.booking,
    child: _content(context),
  );

  Widget _content(BuildContext context) {
    final customers = AppScope.of(context).customers.where((item) {
      final query = _query.toLowerCase();
      return item.name.toLowerCase().contains(query) ||
          item.phone.contains(query);
    }).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Novo agendamento')),
      body: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Step(value: '1 de 5', label: 'Selecionar tutor'),
            const SizedBox(height: 20),
            Text(
              'Para quem é o agendamento?',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 18),
            AppTourTarget(
              id: TipTargets.bookingSearch,
              child: TextField(
                autofocus: true,
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  hintText: 'Buscar por número, nome ou telefone',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            const SizedBox(height: 18),
            ...customers.map(
              (customer) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 7,
                    ),
                    title: Text(
                      customer.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    subtitle: Text(customer.phone),
                    trailing: AppTourTarget(
                      id: TipTargets.bookingCustomer,
                      child: FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(
                            0,
                            AppDimensions.filledButtonHeight,
                          ),
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                PetSelectionScreen(customer: customer),
                          ),
                        ),
                        child: const Text('Selecionar'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            AppTourTarget(
              id: TipTargets.bookingNew,
              child: TextButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CustomerFormScreen(),
                    ),
                  );
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Novo tutor'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.mint,
          borderRadius: AppRadii.r99,
        ),
        child: Text(value, style: AppTextStyles.primaryStrong),
      ),
      const SizedBox(width: 9),
      Text(label, style: AppTextStyles.strong),
    ],
  );
}
