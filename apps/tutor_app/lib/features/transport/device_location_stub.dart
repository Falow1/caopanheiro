import 'device_location.dart';

/// Outside the browser there is no location of the device for the Tutor.
Future<DevicePoint> readDeviceLocation() async =>
    throw const DeviceLocationException(DeviceLocationProblem.unsupported);
