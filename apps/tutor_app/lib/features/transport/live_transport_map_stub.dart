import 'package:flutter/material.dart';

/// Outside the browser there is no map page; the card still shows the time
/// of the last position.
class LiveTransportMap extends StatelessWidget {
  const LiveTransportMap({
    super.key,
    required this.latitude,
    required this.longitude,
    this.accuracy,
  });
  final double latitude;
  final double longitude;
  final num? accuracy;
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Mapa do entregador disponível no navegador.'));
}
