import 'dart:io';

import 'app_failure.dart';

/// A socket opens fast here, so calls check the server before going out.
const bool probeBeforeCalls = true;

/// Null when the server answers. Otherwise, whether this device has any
/// network: Wi-Fi without internet still counts, since nothing outside the
/// device and the server is queried.
Future<NetworkProblem?> probeConnection(
  String host, {
  int port = 5001,
  Future<bool> Function()? hasNetwork,
  Future<void> Function()? reachServer,
}) async {
  try {
    await (reachServer ?? () => _reach(host, port))();
    return null;
  } catch (error) {
    if (_noRoute(error)) return NetworkProblem.noInternet;
    try {
      return await (hasNetwork ?? _hasNetwork)()
          ? NetworkProblem.serverUnreachable
          : NetworkProblem.noInternet;
    } catch (_) {
      return NetworkProblem.serverUnreachable;
    }
  }
}

/// ENETUNREACH (Linux and Android, Apple, Windows): the device has no route at
/// all. Android in airplane mode can keep an address, as the emulator keeps
/// eth0, so the interface list alone would point at the server.
bool _noRoute(Object error) =>
    error is SocketException &&
    const {101, 51, 10051}.contains(error.osError?.errorCode);

Future<void> _reach(String host, int port) async {
  final socket = await Socket.connect(
    host,
    port,
    timeout: const Duration(seconds: 2),
  );
  socket.destroy();
}

/// An interface with a routable address; loopback and link-local do not count.
Future<bool> _hasNetwork() async {
  final interfaces = await NetworkInterface.list();
  return interfaces.any(
    (item) => item.addresses.any(
      (address) => !address.isLoopback && !address.isLinkLocal,
    ),
  );
}
