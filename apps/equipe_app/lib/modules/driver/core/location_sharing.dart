import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/models.dart';

/// Steps in which the driver is on the way and the position is shared.
const routeStatuses = {
  TransportStatus.goingToOrigin,
  TransportStatus.petCollected,
  TransportStatus.inTransit,
};

/// One position read by the phone; [accuracy] in meters.
class PositionFix {
  const PositionFix(this.latitude, this.longitude, [this.accuracy]);
  final double latitude;
  final double longitude;
  final double? accuracy;
}

/// What the phone allows for the location of this app.
enum LocationAccess { granted, denied, deniedForever, serviceOff }

/// Positions of the phone: [DevicePositionSource] on the device, a fake in
/// the tests.
abstract interface class PositionSource {
  /// Current access; with [ask], the system asks the person when it can.
  Future<LocationAccess> access({required bool ask});

  /// Positions while listened to. On Android, listening keeps a foreground
  /// service with a fixed notification, so it goes on with the app in the
  /// background or the screen off.
  Stream<PositionFix> watch();

  /// System settings that solve [access]: the app permission or the
  /// location of the phone.
  Future<void> openSettings(LocationAccess access);
}

/// Sends a position to the server for one petshop.
typedef LocationReport =
    Future<void> Function(String tenantId, PositionFix fix);

enum LocationSharingStatus {
  /// No transport of the driver on the way.
  off,
  starting,
  sharing,

  /// Permission refused; the system can ask again.
  needsPermission,

  /// Permission refused for good: only the app settings change it.
  blocked,

  /// Location turned off on the phone.
  serviceOff,

  /// The phone stopped giving positions.
  unavailable,
}

/// Live position of the driver while a transport is on the way
/// ([routeStatuses]). Positions go to the server at most once per
/// [interval]; a report that fails is not repeated, the next one replaces it.
/// The permission is asked once per session, when the first transport sets
/// out; after that, only through [retry] (button on the transport screen).
class DriverLocationSharing extends ChangeNotifier {
  DriverLocationSharing(
    this._positions,
    this._report, {
    this.interval = const Duration(seconds: 15),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;
  final PositionSource _positions;
  final LocationReport _report;
  final Duration interval;
  final DateTime Function() _now;

  Set<String> _tenants = const {};
  StreamSubscription<PositionFix>? _subscription;
  LocationSharingStatus _status = LocationSharingStatus.off;
  bool _asked = false;
  bool _sending = false;
  int _run = 0;
  DateTime? _lastTry;
  DateTime? _lastSent;

  LocationSharingStatus get status => _status;

  /// Last position the server received in this trip, for the screen.
  DateTime? get lastSentAt => _lastSent;

  /// Petshops with a transport of the driver on the way. Starts the
  /// position with the first one and stops it after the last one.
  Future<void> follow(Set<String> tenants) async {
    final wasActive = _tenants.isNotEmpty;
    _tenants = Set.unmodifiable(tenants);
    if (_tenants.isEmpty) {
      if (wasActive) _stop();
      return;
    }
    if (!wasActive) await _start(ask: !_asked);
  }

  /// Asks the permission again, or opens the system settings when only they
  /// can change it.
  Future<void> retry() async {
    if (_tenants.isEmpty) return;
    if (_status == LocationSharingStatus.blocked ||
        _status == LocationSharingStatus.serviceOff) {
      final access = await _positions.access(ask: false);
      if (access != LocationAccess.granted) {
        await _positions.openSettings(access);
        return;
      }
    }
    await _start(ask: true);
  }

  Future<void> _start({required bool ask}) async {
    final run = ++_run;
    await _subscription?.cancel();
    _subscription = null;
    _set(LocationSharingStatus.starting);
    LocationAccess access;
    try {
      access = await _positions.access(ask: ask);
    } catch (_) {
      access = LocationAccess.denied;
    }
    if (ask) _asked = true;
    if (run != _run || _tenants.isEmpty) return;
    if (access != LocationAccess.granted) {
      _set(switch (access) {
        LocationAccess.deniedForever => LocationSharingStatus.blocked,
        LocationAccess.serviceOff => LocationSharingStatus.serviceOff,
        _ => LocationSharingStatus.needsPermission,
      });
      return;
    }
    try {
      _subscription = _positions.watch().listen(
        (fix) => _send(run, fix),
        onError: (Object _) {
          if (run == _run) _set(LocationSharingStatus.unavailable);
        },
      );
    } catch (_) {
      _set(LocationSharingStatus.unavailable);
      return;
    }
    _set(LocationSharingStatus.sharing);
  }

  Future<void> _send(int run, PositionFix fix) async {
    final now = _now();
    final last = _lastTry;
    if (_sending || last != null && now.difference(last) < interval) return;
    _sending = true;
    _lastTry = now;
    var sent = false;
    try {
      for (final tenant in _tenants.toList()) {
        try {
          await _report(tenant, fix);
          sent = true;
        } catch (_) {
          // No connection or the trip ended meanwhile: the next position
          // tries again, and the transport list stops it when it ends.
        }
      }
    } finally {
      _sending = false;
    }
    if (run != _run) return;
    if (sent) _lastSent = _now();
    _set(LocationSharingStatus.sharing);
  }

  void _stop() {
    ++_run;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _lastTry = null;
    _lastSent = null;
    _set(LocationSharingStatus.off);
  }

  /// Leaves the session: stops the position and asks again next time.
  void reset() {
    _tenants = const {};
    _asked = false;
    _stop();
  }

  void _set(LocationSharingStatus status) {
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }
}

/// Position of the phone through geolocator.
class DevicePositionSource implements PositionSource {
  const DevicePositionSource();

  @override
  Future<LocationAccess> access({required bool ask}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.serviceOff;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && ask) {
      permission = await Geolocator.requestPermission();
    }
    final access = switch (permission) {
      LocationPermission.always ||
      LocationPermission.whileInUse => LocationAccess.granted,
      LocationPermission.deniedForever => LocationAccess.deniedForever,
      _ => LocationAccess.denied,
    };
    if (ask &&
        access == LocationAccess.granted &&
        defaultTargetPlatform == TargetPlatform.android) {
      // The fixed notification of the position service; refused, the
      // position is still shared and the notification stays hidden.
      try {
        await _notices.invokeMethod<bool>('requestNotifications');
      } catch (_) {}
    }
    return access;
  }

  static const _notices = MethodChannel('caopanheiro/notifications');

  @override
  Stream<PositionFix> watch() => Geolocator.getPositionStream(
    locationSettings: defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            intervalDuration: const Duration(seconds: 10),
            // Android's own location (fused provider on Android 12+, GPS
            // before): the Play Services path checks the location settings
            // first and, with Location Accuracy off, ends the stream from the
            // foreground service without offering to turn it on.
            forceLocationManager: true,
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'Transporte a caminho',
              notificationText:
                  'O tutor e a equipe veem sua localização até a entrega.',
              notificationChannelName: 'Localização do transporte',
              enableWakeLock: true,
              setOngoing: true,
            ),
          )
        : const LocationSettings(accuracy: LocationAccuracy.high),
  ).map((p) => PositionFix(p.latitude, p.longitude, p.accuracy));

  @override
  Future<void> openSettings(LocationAccess access) async {
    if (access == LocationAccess.serviceOff) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }
}
