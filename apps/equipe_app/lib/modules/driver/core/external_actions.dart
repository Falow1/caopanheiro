import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../domain/models/transport_address.dart';

/// Opens a link in another app, as `launchUrl` does.
typedef UrlOpener = Future<bool> Function(Uri url, {LaunchMode mode});

Uri transportMapUri(TransportAddress address) => address.hasPoint
    ? Uri.https('www.openstreetmap.org', '/', {
        'mlat': '${address.latitude}',
        'mlon': '${address.longitude}',
      }).replace(fragment: 'map=18/${address.latitude}/${address.longitude}')
    : Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': address.fullAddress,
      });

/// Map centered on a position, for the team to see where the driver is.
Uri positionMapUri(double latitude, double longitude) => Uri.https(
  'www.openstreetmap.org',
  '/',
  {'mlat': '$latitude', 'mlon': '$longitude'},
).replace(fragment: 'map=17/$latitude/$longitude');

Future<bool> openPositionMap(
  double latitude,
  double longitude, {
  UrlOpener open = launchUrl,
}) => _tryOpen(
  open,
  positionMapUri(latitude, longitude),
  LaunchMode.externalApplication,
);

Future<bool> openTransportRoute(
  TransportAddress address, {
  UrlOpener open = launchUrl,
}) => _tryOpen(open, transportMapUri(address), LaunchMode.externalApplication);

Future<bool> callPhone(String phone, {UrlOpener open = launchUrl}) =>
    _tryOpen(open, Uri(scheme: 'tel', path: phone), LaunchMode.platformDefault);

/// On Android, url_launcher answers a link that no installed app opens with
/// an exception instead of false. The screens show their own message on
/// false, so the exception becomes false here.
Future<bool> _tryOpen(UrlOpener open, Uri url, LaunchMode mode) async {
  try {
    return await open(url, mode: mode);
  } on PlatformException {
    return false;
  }
}
