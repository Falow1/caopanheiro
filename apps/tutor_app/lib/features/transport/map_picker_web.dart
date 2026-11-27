import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:flutter/material.dart';
import 'package:caopanheiro_core/caopanheiro_core.dart' show newRecordId;

/// The map of the address (transport-map.html, OpenStreetMap): a tap marks
/// the point and the marker can be dragged; [point] shows the current one,
/// and a new [point] from outside (search, location of the device) moves the
/// marker without reloading the map.
class MapPicker extends StatefulWidget {
  const MapPicker({
    super.key,
    this.center,
    this.point,
    required this.onSelected,
  });
  final Map<String, dynamic>? center;
  final Map<String, dynamic>? point;
  final void Function(double lat, double lng) onSelected;
  @override
  State<MapPicker> createState() => _MapPickerState();
}

class _MapPickerState extends State<MapPicker> {
  final _channel = newRecordId();
  web.HTMLIFrameElement? _frame;
  late final JSFunction _listener;
  // The last point the map itself reported, so it is not sent back.
  (double, double)? _fromMap;

  static (double, double)? _pair(Map<String, dynamic>? value) {
    final lat = value?['lat'], lng = value?['lng'];
    return lat is num && lng is num ? (lat.toDouble(), lng.toDouble()) : null;
  }

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
          _fromMap = (lat.toDouble(), lng.toDouble());
          widget.onSelected(lat.toDouble(), lng.toDouble());
        }
      } catch (_) {
        /* Ignore unrelated browser messages. */
      }
    }).toJS;
    web.window.addEventListener('message', _listener);
  }

  @override
  void didUpdateWidget(MapPicker old) {
    super.didUpdateWidget(old);
    final point = _pair(widget.point);
    if (point == null || point == _pair(old.point) || point == _fromMap) {
      return;
    }
    _frame?.contentWindow?.postMessage(
      jsonEncode({'channel': _channel, 'lat': point.$1, 'lng': point.$2}).toJS,
      Uri.base.origin.toJS,
    );
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
      final point = _pair(widget.point);
      final center = point ?? _pair(widget.center);
      final uri = Uri.base
          .resolve('transport-map.html')
          .replace(
            queryParameters: {
              'channel': _channel,
              'lat': '${center?.$1 ?? -15.601}',
              'lng': '${center?.$2 ?? -56.097}',
              if (point != null) 'marker': '1',
            },
          );
      frame.src = uri.toString();
    },
  );
}
