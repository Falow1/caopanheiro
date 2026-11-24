import 'package:flutter/material.dart';
import 'package:tutor_app/core/theme/app_theme.dart';
import 'package:tutor_app/features/transport/map_picker_web.dart';

// Browser QA entry only. The normal app always starts at lib/main.dart.
void main() =>
    runApp(MaterialApp(theme: AppTheme.light, home: const _MapPreview()));

class _MapPreview extends StatefulWidget {
  const _MapPreview();
  @override
  State<_MapPreview> createState() => _MapPreviewState();
}

class _MapPreviewState extends State<_MapPreview> {
  String _message = 'Toque no mapa para selecionar o ponto';
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Local de coleta',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(_message),
              const SizedBox(height: 12),
              SizedBox(
                height: 360,
                child: MapPicker(
                  center: const {'lat': -15.602, 'lng': -56.095},
                  onSelected: (lat, lng) => setState(
                    () => _message =
                        'Ponto recebido pelo PWA: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
