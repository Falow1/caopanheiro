import 'package:flutter/material.dart';
import 'transport_management_screen.dart';
import 'transport_requests_screen.dart';

class TransportOperationsLinks extends StatelessWidget {
  const TransportOperationsLinks({super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OutlinedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TransportManagementScreen()),
        ),
        icon: const Icon(Icons.local_shipping_outlined),
        label: const Text('Gerenciar transportes'),
      ),
      OutlinedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TransportRequestsScreen()),
        ),
        icon: const Icon(Icons.inbox_outlined),
        label: const Text('Pedidos de transporte dos tutores'),
      ),
    ],
  );
}
