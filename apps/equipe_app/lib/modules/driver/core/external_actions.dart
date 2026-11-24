import 'package:url_launcher/url_launcher.dart';
import '../domain/models/transport_address.dart';

Uri transportMapUri(TransportAddress address) => address.hasPoint
    ? Uri.https('www.openstreetmap.org', '/', {
        'mlat': '${address.latitude}',
        'mlon': '${address.longitude}',
      }).replace(fragment: 'map=18/${address.latitude}/${address.longitude}')
    : Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': address.fullAddress,
      });

Future<bool> openTransportRoute(TransportAddress address) =>
    launchUrl(transportMapUri(address), mode: LaunchMode.externalApplication);

Future<bool> callPhone(String phone) =>
    launchUrl(Uri(scheme: 'tel', path: phone));
