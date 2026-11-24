import 'package:flutter/material.dart';
import '../../state/app_scope.dart';
import 'transport_policy_screen.dart';
import 'transport_operations_links.dart';

class TransportScreen extends StatelessWidget {
  const TransportScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final user = AppScope.of(context).user;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Entre novamente para acessar o transporte.')),
      );
    }
    if (user.isManager && user.canManage('SETTINGS')) {
      return const TransportPolicyScreen();
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Transporte')),
      body: const Padding(
        padding: EdgeInsets.all(20),
        child: TransportOperationsLinks(),
      ),
    );
  }
}
