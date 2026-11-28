import 'package:flutter/material.dart';

class MapPicker extends StatelessWidget {
  const MapPicker({
    super.key,
    this.center,
    this.point,
    this.enabled = true,
    required this.onSelected,
  });
  final Map<String, dynamic>? center;
  final Map<String, dynamic>? point;
  final bool enabled;
  final void Function(double lat, double lng) onSelected;
  @override
  Widget build(BuildContext context) => const Center(
    child: Text(
      'Seleção de mapa disponível no navegador. Você também pode buscar o endereço.',
    ),
  );
}
