import 'dart:convert';
import 'dart:js_interop';

import 'package:caopanheiro_core/caopanheiro_core.dart' show newRecordId;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Map with the driver of a transport on the way (web/transport-live.html).
/// A new position moves the marker by a message to the map, without
/// loading it again.
class LiveTransportMap extends StatefulWidget {
  const LiveTransportMap({
    super.key,
    required this.latitude,
    required this.longitude,
    this.accuracy,
  });
  final double latitude;
  final double longitude;

  /// Meters, as reported by the phone of the driver.
  final num? accuracy;
  @override
  State<LiveTransportMap> createState() => _LiveTransportMapState();
}

class _LiveTransportMapState extends State<LiveTransportMap> {
  final _channel = newRecordId();
  web.HTMLIFrameElement? _frame;

  @override
  void didUpdateWidget(LiveTransportMap old) {
    super.didUpdateWidget(old);
    if (old.latitude == widget.latitude &&
        old.longitude == widget.longitude &&
        old.accuracy == widget.accuracy) {
      return;
    }
    // Only this app's own origin receives it (the map page is served here).
    _frame?.contentWindow?.postMessage(
      jsonEncode({
        'channel': _channel,
        'lat': widget.latitude,
        'lng': widget.longitude,
        'accuracy': widget.accuracy,
      }).toJS,
      Uri.base.origin.toJS,
    );
  }

  @override
  Widget build(BuildContext context) => HtmlElementView.fromTagName(
    tagName: 'iframe',
    onElementCreated: (element) {
      final frame = element as web.HTMLIFrameElement;
      _frame = frame;
      frame.title = 'Mapa com a posição do entregador';
      frame.style.border = '0';
      frame.style.width = '100%';
      frame.style.height = '100%';
      frame.src = Uri.base
          .resolve('transport-live.html')
          .replace(
            queryParameters: {
              'channel': _channel,
              'lat': '${widget.latitude}',
              'lng': '${widget.longitude}',
              if (widget.accuracy != null) 'accuracy': '${widget.accuracy}',
            },
          )
          .toString();
    },
  );
}
