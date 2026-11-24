import 'package:flutter/material.dart';
import '../../../domain/models.dart';
import '../../../core/app_theme.dart';

class AddressCard extends StatelessWidget {
  const AddressCard({
    super.key,
    required this.title,
    required this.address,
    this.onRoute,
    this.onCall,
    this.highlighted = false,
  });
  final String title;
  final TransportAddress address;
  final VoidCallback? onRoute;
  final VoidCallback? onCall;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => Card(
    color: highlighted ? AppColors.mint : AppColors.paper,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          Text(address.name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 3),
          Text(address.street),
          Text(address.district),
          if (onRoute != null || onCall != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (onRoute != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onRoute,
                      icon: const Icon(Icons.navigation_outlined),
                      label: const Text('Abrir rota'),
                    ),
                  ),
                if (onRoute != null && onCall != null) const SizedBox(width: 9),
                if (onCall != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onCall,
                      icon: const Icon(Icons.phone_outlined),
                      label: const Text('Ligar'),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}
