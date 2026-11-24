import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:flutter/material.dart';
import 'package:caopanheiro_core/caopanheiro_core.dart' show newRecordId;

class MapPicker extends StatefulWidget {
  const MapPicker({super.key, this.center, required this.onSelected});
  final Map<String, dynamic>? center;
  final void Function(double lat, double lng) onSelected;
  @override
  State<MapPicker> createState() => _MapPickerState();
}

class _MapPickerState extends State<MapPicker> {
  final _channel = newRecordId();
  web.HTMLIFrameElement? _frame;
  late final JSFunction _listener;
  @override
  void initState() {
    super.initState();
    _listener = ((web.Event event) {
      final e = event as web.MessageEvent;
      if (e.origin != Uri.base.origin || e.source != _frame?.contentWindow) {
        return;
      }
      try {
        final value =
            jsonDecode((e.data as JSString).toDart) as Map<String, dynamic>;
        if (value['channel'] != _channel) return;
        final lat = value['lat'], lng = value['lng'];
        if (lat is num &&
            lng is num &&
            lat.isFinite &&
            lng.isFinite &&
            lat >= -90 &&
            lat <= 90 &&
            lng >= -180 &&
            lng <= 180) {
          widget.onSelected(lat.toDouble(), lng.toDouble());
        }
      } catch (_) {
        /* Ignore unrelated browser messages. */
      }
    }).toJS;
    web.window.addEventListener('message', _listener);
  }

  @override
  void dispose() {
    web.window.removeEventListener('message', _listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView.fromTagName(
    tagName: 'iframe',
    onElementCreated: (element) {
      final frame = element as web.HTMLIFrameElement;
      _frame = frame;
      frame.title = 'Marcar endereço no OpenStreetMap';
      frame.style.border = '0';
      frame.style.width = '100%';
      frame.style.height = '100%';
      final uri = Uri.base
          .resolve('transport-map.html')
          .replace(
            queryParameters: {
              'channel': _channel,
              'lat': '${widget.center?['lat'] ?? -15.601}',
              'lng': '${widget.center?['lng'] ?? -56.097}',
            },
          );
      frame.src = uri.toString();
    },
  );
}
