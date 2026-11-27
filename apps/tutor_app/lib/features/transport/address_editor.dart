import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppColors;
import 'package:flutter/material.dart';

import '../../domain/repositories/tutor_address_repository.dart';
import '../navigation/tutor_wide_layout.dart';
import 'device_location.dart';
import 'map_picker_stub.dart'
    if (dart.library.js_interop) 'map_picker_web.dart';

/// The address being written, shared by the transport of the booking and the
/// personal data: the street and the district typed, and the point on the
/// map, marked by a tap, by the marker dragged, by a search result or by the
/// location of the device. A point from the map fills the street and the
/// district that are empty or were filled by an earlier point; what the tutor
/// types is never replaced.
class AddressEditingController extends ChangeNotifier {
  AddressEditingController({
    TutorAddress? initial,
    required this.search,
    this.reverse,
    this.locate = currentDeviceLocation,
  }) {
    if (initial != null) {
      street.text = initial.street;
      district.text = initial.district;
      point = initial.point;
      _pointKept = true;
    }
  }

  /// Places found for the typed street.
  final Future<List<Map<String, dynamic>>> Function(String query) search;

  /// Street and district of a point; null where the app cannot ask.
  final Future<ReversedAddress?> Function(double lat, double lng)? reverse;

  /// Location of the device, read only when the tutor asks.
  final Future<DevicePoint> Function() locate;

  final street = TextEditingController();
  final district = TextEditingController();
  Map<String, dynamic>? point;
  List<Map<String, dynamic>> places = [];
  bool busy = false;

  /// What went wrong, in red; [info] says what happened, in grey.
  String? error;
  String? info;

  /// Moves on every change of the address itself (not of [busy] or the
  /// messages): a quote of an older address is no longer valid.
  int revision = 0;

  // A point from the map, the device or the account stays when the street
  // is corrected; a point of a search result belongs to its text.
  bool _pointKept = false;
  bool _autoStreet = false, _autoDistrict = false;
  int _reverse = 0;

  /// The complete address, or null while the street, the district or the
  /// point is missing.
  TutorAddress? get value {
    final lat = point?['lat'], lng = point?['lng'];
    if (lat is! num || lng is! num) return null;
    if (street.text.trim().length < 3 || district.text.trim().isEmpty) {
      return null;
    }
    return TutorAddress(
      street: street.text.trim(),
      district: district.text.trim(),
      lat: lat.toDouble(),
      lng: lng.toDouble(),
    );
  }

  void _changed() {
    revision++;
    notifyListeners();
  }

  /// True when nothing of the address is written or marked.
  bool get empty =>
      street.text.trim().isEmpty &&
      district.text.trim().isEmpty &&
      point == null;

  /// Clears the street, the district and the point.
  void clear() {
    street.clear();
    district.clear();
    point = null;
    places = [];
    error = info = null;
    _pointKept = _autoStreet = _autoDistrict = false;
    _reverse++;
    _changed();
  }

  void streetEdited() {
    _autoStreet = false;
    places = [];
    if (!_pointKept) point = null;
    _changed();
  }

  void districtEdited() {
    _autoDistrict = false;
    _changed();
  }

  Future<void> searchStreet() async {
    final query = street.text.trim();
    if (query.length < 5) {
      error = 'Escreva a rua, o número e a cidade para buscar.';
      notifyListeners();
      return;
    }
    busy = true;
    error = info = null;
    places = [];
    notifyListeners();
    try {
      places = await search(query);
      if (places.isEmpty) {
        error =
            'Nenhum endereço encontrado. Complete a busca ou marque no mapa.';
      }
    } catch (e) {
      error = e is FormatException ? e.message : e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void choosePlace(Map<String, dynamic> place) {
    point = Map<String, dynamic>.from(place['point'] as Map);
    _pointKept = false;
    places = [];
    info = 'Ponto do endereço marcado no mapa. Arraste o marcador se precisar.';
    error = null;
    _changed();
  }

  /// A point marked on the map or read from the device.
  Future<void> setPoint(double lat, double lng, {String? note}) async {
    point = {'lat': lat, 'lng': lng};
    _pointKept = true;
    places = [];
    error = null;
    info = note;
    _changed();
    final reverse = this.reverse;
    if (reverse == null) return;
    final request = ++_reverse;
    try {
      final found = await reverse(lat, lng);
      if (request != _reverse) return;
      final fillStreet = street.text.trim().isEmpty || _autoStreet;
      final fillDistrict = district.text.trim().isEmpty || _autoDistrict;
      if (found == null || found.street.isEmpty) {
        if (fillStreet) {
          info = [
            ?note,
            'Não achamos a rua deste ponto. Escreva o endereço com o número.',
          ].join(' ');
        }
        notifyListeners();
        return;
      }
      if (fillStreet) {
        street.text = found.street;
        _autoStreet = true;
      }
      if (fillDistrict && found.district.isNotEmpty) {
        district.text = found.district;
        _autoDistrict = true;
      }
      if (fillStreet || fillDistrict) {
        info = [
          ?note,
          'Endereço preenchido pelo ponto. Confira o número e o complemento.',
        ].join(' ');
      }
      _changed();
    } catch (_) {
      // Without the street of the point the tutor writes it; the point stays.
      if (request == _reverse && (street.text.trim().isEmpty)) {
        info = [
          ?note,
          'Escreva o endereço com o número; o ponto do mapa foi marcado.',
        ].join(' ');
        notifyListeners();
      }
    }
  }

  Future<void> useDeviceLocation() async {
    busy = true;
    error = info = null;
    notifyListeners();
    try {
      final here = await locate();
      busy = false;
      await setPoint(
        here.lat,
        here.lng,
        note:
            'Localização do aparelho marcada no mapa${here.accuracy > 0 && here.accuracy.isFinite ? ', com precisão de cerca de ${here.accuracy.round()} m' : ''}. Arraste o marcador se precisar.',
      );
    } on DeviceLocationException catch (problem) {
      error = problem.message;
    } catch (_) {
      error = const DeviceLocationException(
        DeviceLocationProblem.unavailable,
      ).message;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    street.dispose();
    district.dispose();
    super.dispose();
  }
}

/// The street, the search, the location of the device and the district, with
/// the messages of the [controller].
class AddressFields extends StatelessWidget {
  const AddressFields({
    super.key,
    required this.controller,
    this.enabled = true,
    this.required = true,
  });
  final AddressEditingController controller;
  final bool enabled;

  /// False where the address is optional (personal data): the page checks
  /// that it is complete when something is written.
  final bool required;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final active = enabled && !controller.busy;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            enabled: active,
            controller: controller.street,
            decoration: const InputDecoration(
              labelText: 'Endereço completo, número e cidade',
              helperText: 'Ex.: Rua das Acácias, 245, Cuiabá',
            ),
            onChanged: (_) => controller.streetEdited(),
            validator: (v) => required && (v?.trim().length ?? 0) < 3
                ? 'Informe o endereço'
                : null,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: active ? controller.searchStreet : null,
                icon: const Icon(Icons.search),
                label: const Text('Buscar endereço'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('address-device-location'),
                onPressed: active ? controller.useDeviceLocation : null,
                icon: const Icon(Icons.my_location_rounded),
                label: const Text('Usar minha localização'),
              ),
            ],
          ),
          if (controller.busy)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: LinearProgressIndicator(),
            ),
          for (final result in controller.places)
            ListTile(
              title: Text(result['label'] as String),
              leading: const Icon(Icons.place_outlined),
              onTap: active ? () => controller.choosePlace(result) : null,
            ),
          const SizedBox(height: 10),
          TextFormField(
            enabled: active,
            controller: controller.district,
            decoration: const InputDecoration(
              labelText: 'Bairro e cidade / complemento',
              helperText: 'Ex.: Centro, Cuiabá · apto 12',
            ),
            onChanged: (_) => controller.districtEdited(),
            validator: (v) => required && (v?.trim().isEmpty ?? true)
                ? 'Informe o bairro/cidade'
                : null,
          ),
          if (controller.error case final error?)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          if (controller.info case final info?)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  info,
                  style: const TextStyle(color: AppColors.muted),
                ),
              ),
            ),
        ],
      );
    },
  );
}

/// The map of the [controller]'s point, [height] tall: under the fields, or
/// beside them when [top] is false. [center] is where it opens without a
/// point, as the petshop.
class AddressMap extends StatelessWidget {
  const AddressMap({
    super.key,
    required this.controller,
    required this.height,
    this.center,
    this.top = true,
    this.enabled = true,
  });
  final AddressEditingController controller;
  final double height;
  final Map<String, dynamic>? center;
  final bool top;
  final bool enabled;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (top) const SizedBox(height: 12),
        Text(
          // With a mouse the point is marked with a click.
          '${tutorWide(context) ? 'Ou clique' : 'Ou toque'} no mapa para marcar o ponto e arraste o marcador para ajustar. Confira o número e o complemento no endereço ${top ? 'acima' : 'ao lado'}.',
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: height,
          child: MapPicker(
            center: center,
            point: controller.point,
            onSelected: (lat, lng) {
              if (enabled && !controller.busy) controller.setPoint(lat, lng);
            },
          ),
        ),
        if (controller.point != null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Ponto selecionado. Confira o endereço antes de continuar.',
            ),
          ),
        const Text(
          'Busca e mapa © OpenStreetMap contributors. O endereço consultado e os pontos do mapa e da rota são enviados aos serviços de mapas.',
        ),
      ],
    ),
  );
}
