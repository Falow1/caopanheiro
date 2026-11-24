import 'package:flutter/widgets.dart';

import '../state/app_controller.dart';
import '../state/app_scope.dart';

/// Screens that read their own list (plan, support, transports) follow the
/// live refresh of the controller: after each live reload of the open
/// petshop, they read again without loading state.
mixin LiveScreenReload<T extends StatefulWidget> on State<T> {
  AppController? _liveController;
  int _liveSeen = 0;

  /// Reads the screen again quietly, keeping what is shown on failure.
  void liveScreenReload();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = AppScope.of(context);
    if (identical(controller, _liveController)) return;
    _liveController?.removeListener(_liveChanged);
    _liveController = controller..addListener(_liveChanged);
    _liveSeen = controller.liveRevision;
  }

  void _liveChanged() {
    final revision = _liveController!.liveRevision;
    if (revision == _liveSeen) return;
    _liveSeen = revision;
    if (mounted) liveScreenReload();
  }

  @override
  void dispose() {
    _liveController?.removeListener(_liveChanged);
    super.dispose();
  }
}
