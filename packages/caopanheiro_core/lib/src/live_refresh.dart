import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';

import 'app_controller_base.dart';

/// Source of change signals. A signal holds only a counter written by the
/// server when something changed; it never carries business data, which the
/// apps keep reading through the authorized server queries.
abstract interface class LiveSignalSource {
  /// UID of the signed-in account, used in the tutor's own signal path.
  String? get uid;

  /// Emits the signal's revision now and each time it changes.
  Stream<int> watch(String path);
}

/// Repositories that can offer live signals implement this capability, so
/// test doubles without it keep working with manual refresh only.
abstract interface class LiveSignalsAware {
  LiveSignalSource? get liveSignals;
}

/// Paths of the signals written by backend/src/live_signals.js.
abstract final class LiveSignalPaths {
  static String team(String tenantId) => 'tenants/$tenantId/liveSignals/team';
  static String catalog(String tenantId) =>
      'tenants/$tenantId/liveSignals/catalog';
  static String tutor(String tenantId, String uid) =>
      'tenants/$tenantId/liveSignals/tutor-$uid';
  static const platform = 'platformSignals/admin';
}

class FirestoreLiveSignals implements LiveSignalSource {
  FirestoreLiveSignals(this._db, this._uid);
  final FirebaseFirestore _db;
  final String? Function() _uid;
  @override
  String? get uid => _uid();
  @override
  Stream<int> watch(String path) => serverRevisions(
    _db
        .doc(path)
        .snapshots()
        .map(
          (snapshot) => (
            fromCache: snapshot.metadata.isFromCache,
            revision: (snapshot.data()?['revision'] as num?)?.toInt() ?? 0,
          ),
        ),
  );
}

/// Revisions confirmed by the server only. On a new watch (as on returning
/// to the app) Firestore may first answer from its local cache with an old
/// revision and then from the server with the current one; that pair would
/// look like a change and read the screens again right after their own
/// refresh. Without a connection nothing is emitted, as nothing can change.
@visibleForTesting
Stream<int> serverRevisions(
  Stream<({bool fromCache, int revision})> snapshots,
) => snapshots
    .where((snapshot) => !snapshot.fromCache)
    .map((snapshot) => snapshot.revision);

/// Calls [onChange] shortly after any watched signal moves.
///
/// The first value of each signal is only the starting point. Changes close
/// together are joined into one call, and two calls are at least
/// [minInterval] apart: a change seen while waiting is kept and calls
/// [onChange] once when the wait ends, so every reload reads the whole
/// petshop at most once per interval. A signal that fails (no permission,
/// connection lost) stops silently: the manual refresh keeps working. While
/// the app is hidden nothing is watched; on return the screens already do a
/// refresh of their own, and the watch restarts from the current values.
class LiveRefresh {
  LiveRefresh({
    required LiveSignalSource source,
    required this.onChange,
    this.delay = const Duration(milliseconds: 700),
    this.minInterval = const Duration(seconds: 5),
    bool followLifecycle = true,
  }) : _source = source {
    if (followLifecycle) {
      _lifecycle = AppLifecycleListener(onHide: _pause, onShow: _resume);
    }
  }

  final LiveSignalSource _source;
  final VoidCallback onChange;
  final Duration delay;
  final Duration minInterval;
  AppLifecycleListener? _lifecycle;
  final _subscriptions = <String, StreamSubscription<int>>{};
  Set<String> _paths = {};
  Timer? _timer, _cooldown;
  bool _hidden = false, _disposed = false, _pending = false;

  String? get uid => _source.uid;
  Set<String> get paths => Set.unmodifiable(_paths);

  /// Replaces the watched signals; unchanged ones keep their subscription.
  void watch(Iterable<String> paths) {
    if (_disposed) return;
    final next = paths.toSet();
    for (final path in _paths.difference(next)) {
      unawaited(_subscriptions.remove(path)?.cancel());
    }
    _paths = next;
    if (!_hidden) _subscribeMissing();
  }

  void _subscribeMissing() {
    for (final path in _paths) {
      if (_subscriptions.containsKey(path)) continue;
      int? last;
      _subscriptions[path] = _source
          .watch(path)
          .listen(
            (revision) {
              final previous = last;
              last = revision;
              if (previous != null && previous != revision) _schedule();
            },
            onError: (Object _) =>
                unawaited(_subscriptions.remove(path)?.cancel()),
            cancelOnError: true,
          );
    }
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(delay, _fire);
  }

  void _fire() {
    if (_disposed || _hidden) return;
    if (_cooldown?.isActive ?? false) {
      _pending = true;
      return;
    }
    onChange();
    _cooldown = Timer(minInterval, () {
      if (!_pending) return;
      _pending = false;
      _fire();
    });
  }

  void _cancelAll() {
    _timer?.cancel();
    _cooldown?.cancel();
    _pending = false;
    for (final subscription in _subscriptions.values) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
  }

  void _pause() {
    _hidden = true;
    _cancelAll();
  }

  void _resume() {
    if (_disposed) return;
    _hidden = false;
    _subscribeMissing();
  }

  void stop() {
    _paths = {};
    _cancelAll();
  }

  void dispose() {
    _disposed = true;
    _lifecycle?.dispose();
    _cancelAll();
  }
}

/// Live refresh for a controller: after every state change it checks which
/// signals the current session should follow, and when one moves it runs
/// [liveReload] through [AppControllerBase.runQuietly]. [liveRevision] grows
/// after each live reload, so widgets that read on their own (such as the
/// notice bells) can follow it.
mixin LiveFollowing on AppControllerBase {
  LiveRefresh? _live;
  int _liveRevision = 0;
  bool _liveDisposed = false;

  int get liveRevision => _liveRevision;

  /// Null when the repository has no live signals (offline test doubles).
  @protected
  LiveSignalSource? get liveSource;

  /// Signals for the current session; empty stops following.
  @protected
  Iterable<String> livePaths(String uid);

  /// The same queries of the manual refresh, without loading state.
  @protected
  Future<void> liveReload();

  Future<bool> liveRefresh() async {
    final done = await runQuietly(() async {
      await liveReload();
      _liveRevision++;
    });
    return done;
  }

  void _followLive() {
    if (_liveDisposed) return;
    final source = liveSource, uid = source?.uid;
    final paths = source == null || uid == null
        ? const <String>[]
        : livePaths(uid).toList();
    if (paths.isEmpty) {
      _live?.stop();
      return;
    }
    _live ??= LiveRefresh(
      source: source!,
      onChange: () => unawaited(liveRefresh()),
    );
    _live!.watch(paths);
  }

  @override
  void notifyListeners() {
    _followLive();
    super.notifyListeners();
  }

  @override
  void dispose() {
    _liveDisposed = true;
    _live?.dispose();
    super.dispose();
  }
}
