import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'install_support.dart';

InstallSupport createInstallSupport() => const _BrowserInstall();

/// Saved by web/index.html when Chrome announces that it can install.
const _prompt = 'caopanheiroInstallPrompt';

/// Also written by web/index.html when Chrome reports the installation.
const _installedKey = 'caopanheiro.installed';
const _closedKey = 'caopanheiro.installClosed';

class _BrowserInstall extends InstallSupport {
  const _BrowserInstall();

  @override
  InstallDevice get device {
    final agent = web.window.navigator.userAgent;
    if (RegExp('iPhone|iPod').hasMatch(agent)) return InstallDevice.iphone;
    if (agent.contains('Android')) return InstallDevice.android;
    return InstallDevice.other;
  }

  @override
  bool get installed =>
      web.window.matchMedia('(display-mode: standalone)').matches ||
      // Safari's own flag for a page opened from the home screen.
      (web.window.navigator
              .getProperty<JSBoolean?>('standalone'.toJS)
              ?.toDart ??
          false) ||
      _stored(_installedKey);

  @override
  bool get closed => _stored(_closedKey);

  @override
  void close() => _store(_closedKey);

  @override
  Future<InstallResult> prompt() async {
    final event = web.window.getProperty<JSObject?>(_prompt.toJS);
    if (event == null) return InstallResult.unavailable;
    // Chrome opens each saved announcement only once.
    web.window.setProperty(_prompt.toJS, null);
    try {
      await event.callMethod<JSPromise<JSAny?>?>('prompt'.toJS)?.toDart;
      final choice = await event
          .getProperty<JSPromise<JSObject>>('userChoice'.toJS)
          .toDart;
      if (choice.getProperty<JSString?>('outcome'.toJS)?.toDart == 'accepted') {
        _store(_installedKey);
        return InstallResult.accepted;
      }
      return InstallResult.dismissed;
    } catch (_) {
      return InstallResult.unavailable;
    }
  }
}

/// Storage can be blocked, as in private windows; the invitation then
/// simply shows again next time.
bool _stored(String key) {
  try {
    return web.window.localStorage.getItem(key) != null;
  } catch (_) {
    return false;
  }
}

void _store(String key) {
  try {
    web.window.localStorage.setItem(key, '1');
  } catch (_) {
    /* Not remembered on this device. */
  }
}
