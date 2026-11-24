import 'package:flutter/material.dart';
import '../../state/app_scope.dart';
import '../../state/app_controller.dart';

/// Existing operations/history remain outside this gate.
class TransportCreationGate extends StatefulWidget {
  const TransportCreationGate({super.key, required this.child});
  final Widget child;
  @override
  State<TransportCreationGate> createState() => _TransportCreationGateState();
}

class _TransportCreationGateState extends State<TransportCreationGate>
    with WidgetsBindingObserver {
  AppController? _controller;
  String? _company;
  bool? _manager;
  bool _enabled = false;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final c = AppScope.of(context);
    if (c == _controller &&
        c.company?.id == _company &&
        c.user?.isManager == _manager) {
      if (_manager == false) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _load());
      }
      return;
    }
    _controller = c;
    _company = c.company?.id;
    _manager = c.user?.isManager;
    _enabled = _manager == true;
    ++_request;
    if (c.user != null && _manager != true) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    final c = _controller;
    if (c == null || c.user == null || c.user!.isManager) return;
    final request = ++_request;
    bool enabled;
    try {
      enabled = (await c.bookingPolicy())['enabled'] == true;
    } catch (_) {
      enabled = false;
    }
    if (mounted && request == _request) setState(() => _enabled = enabled);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  @override
  void dispose() {
    ++_request;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _enabled ? widget.child : const SizedBox.shrink();
}
