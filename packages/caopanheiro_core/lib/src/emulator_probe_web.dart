import 'dart:async';
import 'dart:js_interop';

import 'app_failure.dart';

@JS('navigator.onLine')
external bool get _browserOnline;

@JS('fetch')
external JSPromise<JSAny?> _fetch(String resource, JSAny? options);

/// The browser checks only after a failure, so calls get no extra request.
const bool probeBeforeCalls = false;

/// Null when the server answers. An opaque request is enough: any answer
/// proves the server is up, and no data is read. Otherwise the browser says
/// whether the device is offline.
Future<NetworkProblem?> probeConnection(
  String host, {
  int port = 5001,
  Future<bool> Function()? hasNetwork,
  Future<void> Function()? reachServer,
}) async {
  try {
    await (reachServer ?? () => _reach(host, port))();
    return null;
  } catch (_) {
    try {
      final online = hasNetwork == null ? _browserOnline : await hasNetwork();
      return online
          ? NetworkProblem.serverUnreachable
          : NetworkProblem.noInternet;
    } catch (_) {
      return NetworkProblem.serverUnreachable;
    }
  }
}

Future<void> _reach(String host, int port) => _fetch(
  'http://$host:$port/',
  {'mode': 'no-cors', 'cache': 'no-store'}.jsify(),
).toDart.timeout(const Duration(seconds: 2));
