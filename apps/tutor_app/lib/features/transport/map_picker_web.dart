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
    this.enabled = true,
    required this.onSelected,
  });
  final Map<String, dynamic>? center;
  final Map<String, dynamic>? point;
  final bool enabled;
  final void Function(double lat, double lng) onSelected;
  @override
  State<MapPicker> createState() => _MapPickerState();
}

class _MapPickerState extends State<MapPicker> {
  final _channel = newRecordId();
  web.HTMLIFrameElement? _frame;
  late final JSFunction _listener;
  bool _ready = false;
  (double, double)? _shownPoint;
  bool? _shownEnabled;

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
        if (value['ready'] == true) {
          _ready = true;
          _sync(force: true);
          return;
        }
        final lat = value['lat'], lng = value['lng'];
        if (lat is num &&
            lng is num &&
            lat.isFinite &&
            lng.isFinite &&
            lat >= -90 &&
            lat <= 90 &&
            lng >= -180 &&
            lng <= 180) {
          if (!widget.enabled) {
            _sync(force: true);
            return;
          }
          _shownPoint = (lat.toDouble(), lng.toDouble());
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
    _sync();
  }

  void _sync({bool force = false}) {
    final point = _pair(widget.point);
    if (!_ready ||
        (!force && point == _shownPoint && widget.enabled == _shownEnabled)) {
      return;
    }
    _frame?.contentWindow?.postMessage(
      jsonEncode({
        'channel': _channel,
        'point': point == null ? null : {'lat': point.$1, 'lng': point.$2},
        'enabled': widget.enabled,
        'center': point != _shownPoint,
      }).toJS,
      Uri.base.origin.toJS,
    );
    _shownPoint = point;
    _shownEnabled = widget.enabled;
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
      _ready = false;
      _shownEnabled = null;
      frame.title = 'Marcar endereço no OpenStreetMap';
      frame.style.border = '0';
      frame.style.width = '100%';
      frame.style.height = '100%';
      final point = _pair(widget.point);
      _shownPoint = point;
      final center = point ?? _pair(widget.center);
      final uri = Uri.base
          .resolve('transport-map.html')
          .replace(
            queryParameters: {
              'channel': _channel,
              'lat': '${center?.$1 ?? -15.601}',
              'lng': '${center?.$2 ?? -56.097}',
              if (point != null) 'marker': '1',
              if (!widget.enabled) 'disabled': '1',
            },
          );
      frame.src = uri.toString();
    },
  );
}
