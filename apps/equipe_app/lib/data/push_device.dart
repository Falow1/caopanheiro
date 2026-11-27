import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// The part of Firebase Cloud Messaging this app uses; tests give a fake.
abstract interface class PushMessaging {
  /// Asks the permission to notify; false when the person refused.
  Future<bool> requestPermission();

  /// The registration token of this device, which the server sends to.
  Future<String?> token();
  Stream<String> get tokenRefresh;

  /// The data of the push that opened the app, when one did.
  Future<Map<String, String>?> initialTap();

  /// The data of each push tapped while the app was in the background.
  Stream<Map<String, String>> get taps;
}

class FirebasePushMessaging implements PushMessaging {
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  static Map<String, String> _data(RemoteMessage message) =>
      message.data.map((key, value) => MapEntry(key, '$value'));

  @override
  Future<bool> requestPermission() async =>
      (await _messaging.requestPermission()).authorizationStatus !=
      AuthorizationStatus.denied;

  // The registration token, which the Admin SDK of the server sends to. The
  // newer register()/onRegistered gives the installation ID instead.
  @override
  // ignore: deprecated_member_use
  Future<String?> token() => _messaging.getToken();
  @override
  // ignore: deprecated_member_use
  Stream<String> get tokenRefresh => _messaging.onTokenRefresh;

  @override
  Future<Map<String, String>?> initialTap() async {
    final message = await _messaging.getInitialMessage();
    return message == null ? null : _data(message);
  }

  @override
  Stream<Map<String, String>> get taps =>
      FirebaseMessaging.onMessageOpenedApp.map(_data);
}

/// This Android device in the push notifications of the server: asks the
/// permission, sends the token at the entry and when it changes, removes it
/// at the sign out, and tells the screens which push the person tapped. The
/// notification itself is shown by Android.
class PushDevice {
  PushDevice(this._app, this._call, {PushMessaging? messaging, bool? supported})
    : _messaging = messaging ?? FirebasePushMessaging(),
      _supported = supported ?? PushDevice.supported;

  /// 'equipe' or 'saas', as the server knows the apps.
  final String _app;
  final Future<Object?> Function(String name, Map<String, dynamic> data) _call;
  final PushMessaging _messaging;
  final bool _supported;
  StreamSubscription<String>? _refresh;
  StreamSubscription<Map<String, String>>? _taps;
  String? _token;

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// The data of the push the person tapped, until a screen takes it.
  static final opened = ValueNotifier<Map<String, String>?>(null);

  /// Gives the tapped push to the screen that shows it, once.
  static Map<String, String>? take(bool Function(Map<String, String>) fits) {
    final data = opened.value;
    if (data == null || !fits(data)) return null;
    opened.value = null;
    return data;
  }

  Future<void> register() async {
    if (!_supported) return;
    _taps ??= _messaging.taps.listen((data) => opened.value = data);
    final first = await _messaging.initialTap();
    if (first != null) opened.value = first;
    if (!await _messaging.requestPermission()) return;
    final token = await _messaging.token();
    if (token == null) return;
    _token = token;
    await _call('registerPushToken', {'token': token, 'app': _app});
    _refresh ??= _messaging.tokenRefresh.listen((value) {
      _token = value;
      unawaited(
        _call('registerPushToken', {
          'token': value,
          'app': _app,
        }).catchError((Object _) => null),
      );
    });
  }

  /// Before the sign out, while the session still calls the server. Without
  /// connection the server forgets the device later, by the daily purge.
  Future<void> unregister() async {
    final token = _token;
    await _refresh?.cancel();
    _refresh = null;
    _token = null;
    opened.value = null;
    if (token == null) return;
    try {
      await _call('unregisterPushToken', {
        'token': token,
      }).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }
}
