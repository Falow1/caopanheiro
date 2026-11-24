import 'dart:async';

import 'package:flutter/foundation.dart';

import 'app_failure.dart';

abstract class AppControllerBase extends ChangeNotifier {
  bool _busy = false;
  AppFailure? _failure;
  Future<void>? _quietRun;

  bool get busy => _busy;
  AppFailure? get failure => _failure;

  String? get error => _failure?.message;
  bool get offline => _failure?.kind == AppFailureKind.network;

  /// Where the reason of the latest failed call is kept, usually the
  /// repository ([NetworkProblemSource]).
  @protected
  Object? get networkProblemSource => null;

  /// Reason for the connection banner: the failed operation first, then the
  /// latest failure seen by the source; server down when nothing is known.
  NetworkProblem get connectionProblem {
    final source = networkProblemSource;
    return _failure?.networkProblem ??
        (source is NetworkProblemSource ? source.lastNetworkProblem : null) ??
        NetworkProblem.serverUnreachable;
  }

  @protected
  Future<bool> runGuarded(
    Future<void> Function() action, {
    bool treatUnexpectedAsNetwork = false,
  }) async {
    // An action never runs beside a background refresh: it waits for it, so
    // a tap during a live update is not lost.
    while (_quietRun != null) {
      await _quietRun;
    }
    if (_busy) return false;
    _busy = true;
    _failure = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on FormatException catch (exception) {
      _failure = AppFailure(
        kind: AppFailureKind.validation,
        message: exception.message,
      );
      return false;
    } on StateError catch (exception) {
      _failure = AppFailure(
        kind: AppFailureKind.conflict,
        message: exception.message,
      );
      return false;
    } on NetworkException catch (exception) {
      _failure = AppFailure(
        kind: AppFailureKind.network,
        message: exception.message,
        networkProblem: exception.problem,
      );
      return false;
    } catch (_) {
      _failure = AppFailure(
        kind: treatUnexpectedAsNetwork
            ? AppFailureKind.network
            : AppFailureKind.unexpected,
        message: treatUnexpectedAsNetwork
            ? 'Não foi possível confirmar com o servidor. Tente novamente.'
            : 'Não foi possível concluir. Tente novamente.',
      );
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Background refresh for live updates: no loading state, no error on the
  /// screen and no change to [failure]. Skipped while another operation runs.
  /// Returns whether the action finished; listeners are notified only then.
  @protected
  Future<bool> runQuietly(Future<void> Function() action) async {
    if (_busy || _quietRun != null) return false;
    final done = Completer<void>();
    _quietRun = done.future;
    try {
      await action();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    } finally {
      _quietRun = null;
      done.complete();
    }
  }

  @protected
  void clearOperationState({bool notify = true}) {
    _failure = null;
    if (notify) notifyListeners();
  }
}
