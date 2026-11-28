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
      _autoStreet = _autoDistrict = true;
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
  int _request = 0;

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
    _request++;
    busy = false;
    street.clear();
    district.clear();
    point = null;
    places = [];
    error = info = null;
    _pointKept = _autoStreet = _autoDistrict = false;
    _changed();
  }

  void streetEdited() {
    _autoStreet = false;
    places = [];
    if (!_pointKept && point != null) {
      _request++;
      point = null;
      info = null;
    }
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
    final request = ++_request;
    busy = true;
    error = info = null;
    places = [];
    notifyListeners();
    try {
      final results = await search(query);
      if (request != _request) return;
      places = results;
      if (places.isEmpty) {
        error =
            'Nenhum endereço encontrado. Complete a busca ou marque no mapa.';
      }
    } catch (e) {
      if (request == _request) {
        error = e is FormatException ? e.message : e.toString();
      }
    } finally {
      if (request == _request) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> choosePlace(Map<String, dynamic> place) {
    final selected = place['point'] as Map;
    return _selectPoint(
      (selected['lat'] as num).toDouble(),
      (selected['lng'] as num).toDouble(),
      keepOnStreetEdit: false,
      note: 'Endereço selecionado no mapa.',
    );
  }

  /// A point marked on the map or read from the device.
  Future<void> setPoint(double lat, double lng, {String? note}) => _selectPoint(
    lat,
    lng,
    keepOnStreetEdit: true,
    note: note ?? 'Ponto selecionado no mapa.',
  );

  Future<void> _selectPoint(
    double lat,
    double lng, {
    required bool keepOnStreetEdit,
    required String note,
  }) async {
    final request = ++_request;
    busy = false;
    if (point?['lat'] != lat || point?['lng'] != lng) {
      if (_autoStreet) street.clear();
      if (_autoDistrict) district.clear();
    }
    point = {'lat': lat, 'lng': lng};
    _pointKept = keepOnStreetEdit;
    places = [];
    error = null;
    final reverse = this.reverse;
    final needsAddress = value == null;
    info = needsAddress
        ? '$note ${reverse == null ? 'Preencha a rua, o número e o bairro.' : 'Buscando rua e bairro…'}'
        : '$note Confira se a rua, o número e o bairro correspondem ao ponto.';
    _changed();
    if (reverse == null || !needsAddress) return;
    ReversedAddress? found;
    try {
      found = await reverse(lat, lng);
    } catch (_) {
      // The tutor can complete the address without the map service.
    }
    if (request != _request) return;
    final resolvedStreet = found?.street ?? '';
    final resolvedDistrict = found?.district ?? '';
    final fillStreet = street.text.trim().isEmpty && resolvedStreet.isNotEmpty;
    final fillDistrict =
        district.text.trim().isEmpty && resolvedDistrict.isNotEmpty;
    if (fillStreet) {
      street.text = resolvedStreet;
      _autoStreet = true;
    }
    if (fillDistrict) {
      district.text = resolvedDistrict;
      _autoDistrict = true;
    }
    info = value == null
        ? '$note Complete a rua, o número e o bairro para continuar.'
        : '$note Confira o número e o complemento.';
    if (fillStreet || fillDistrict) {
      _changed();
    } else {
      notifyListeners();
    }
  }

  Future<void> useDeviceLocation() async {
    final request = ++_request;
    busy = true;
    error = info = null;
    notifyListeners();
    try {
      final here = await locate();
      if (request != _request) return;
      await setPoint(
        here.lat,
        here.lng,
        note:
            'Localização do aparelho marcada no mapa${here.accuracy > 0 && here.accuracy.isFinite ? ', com precisão de cerca de ${here.accuracy.round()} m' : ''}. Arraste o marcador se precisar.',
      );
    } on DeviceLocationException catch (problem) {
      if (request == _request) error = problem.message;
    } catch (_) {
      if (request == _request) {
        error = const DeviceLocationException(
          DeviceLocationProblem.unavailable,
        ).message;
      }
    } finally {
      if (request == _request) {
        busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _request++;
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
            enabled: enabled,
            onSelected: (lat, lng) {
              if (enabled) controller.setPoint(lat, lng);
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
