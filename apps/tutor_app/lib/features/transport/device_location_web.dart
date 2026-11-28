import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'device_location.dart';

/// The Geolocation API of the browser, once, with high accuracy. A secure
/// page (HTTPS or localhost) is required by the browser.
Future<DevicePoint> readDeviceLocation() {
  final completer = Completer<DevicePoint>();
  final web.Geolocation geolocation;
  try {
    geolocation = web.window.navigator.geolocation;
  } catch (_) {
    return Future.error(
      const DeviceLocationException(DeviceLocationProblem.unsupported),
    );
  }
  geolocation.getCurrentPosition(
    ((web.GeolocationPosition position) {
      if (completer.isCompleted) return;
      final coords = position.coords;
      completer.complete(
        DevicePoint(coords.latitude, coords.longitude, coords.accuracy),
      );
    }).toJS,
    ((web.GeolocationPositionError error) {
      if (completer.isCompleted) return;
      completer.completeError(
        DeviceLocationException(switch (error.code) {
          1 => DeviceLocationProblem.denied,
          3 => DeviceLocationProblem.timeout,
          _ => DeviceLocationProblem.unavailable,
        }),
      );
    }).toJS,
    web.PositionOptions(
      enableHighAccuracy: true,
      timeout: 15000,
      maximumAge: 60000,
    ),
  );
  return completer.future.timeout(
    const Duration(seconds: 20),
    onTimeout: () =>
        throw const DeviceLocationException(DeviceLocationProblem.timeout),
  );
}
