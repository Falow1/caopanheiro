import 'device_location_stub.dart'
    if (dart.library.js_interop) 'device_location_web.dart'
    as platform;

/// A point read once from the device, with its accuracy in meters.
class DevicePoint {
  const DevicePoint(this.lat, this.lng, this.accuracy);
  final double lat;
  final double lng;
  final double accuracy;
}

enum DeviceLocationProblem { denied, unavailable, timeout, unsupported }

class DeviceLocationException implements Exception {
  const DeviceLocationException(this.problem);
  final DeviceLocationProblem problem;

  /// What the tutor reads, with the way out: the map or the typed address.
  String get message => switch (problem) {
    DeviceLocationProblem.denied =>
      'Sem permissão para usar a localização. Marque o ponto no mapa ou escreva o endereço. Para usar a localização, permita o acesso nas configurações do navegador.',
    DeviceLocationProblem.unavailable =>
      'Não foi possível saber a localização do aparelho. Marque o ponto no mapa ou escreva o endereço.',
    DeviceLocationProblem.timeout =>
      'A localização demorou para responder. Tente de novo, marque o ponto no mapa ou escreva o endereço.',
    DeviceLocationProblem.unsupported =>
      'Este navegador não informa a localização. Marque o ponto no mapa ou escreva o endereço.',
  };
}

/// Reads the location of the device once, only when the tutor asks. The
/// browser asks the permission itself the first time.
Future<DevicePoint> currentDeviceLocation() => platform.readDeviceLocation();
