import 'app_failure.dart';

/// Without sockets or a browser, nothing is checked before a call.
const bool probeBeforeCalls = false;

/// No check available: the reason assumed from the error stays.
Future<NetworkProblem?> probeConnection(
  String host, {
  int port = 5001,
  Future<bool> Function()? hasNetwork,
  Future<void> Function()? reachServer,
}) async => null;
