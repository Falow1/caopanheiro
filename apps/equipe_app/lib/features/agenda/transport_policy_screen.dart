import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppColors, AppNoticeBanner, showAppConfirmation;
import 'package:caopanheiro_core/caopanheiro_core.dart'
    show
        PhoneInputFormatter,
        displayPhone,
        formatBrazilPhone,
        phoneHint,
        phoneValidator;
import 'package:flutter/material.dart';
import '../../state/app_scope.dart';
import 'transport_operations_links.dart';

class TransportPolicyScreen extends StatefulWidget {
  const TransportPolicyScreen({super.key});
  @override
  State<TransportPolicyScreen> createState() => _TransportPolicyScreenState();
}

class _TransportPolicyScreenState extends State<TransportPolicyScreen> {
  final _form = GlobalKey<FormState>();
  final _address = TextEditingController(),
      _district = TextEditingController(),
      _phone = TextEditingController();
  final _base = TextEditingController(),
      _minimum = TextEditingController(),
      _perKm = TextEditingController(),
      _limit = TextEditingController();
  List<TextEditingController> get _fields => [
    _address,
    _district,
    _phone,
    _base,
    _minimum,
    _perKm,
    _limit,
  ];
  Map<String, dynamic>? _point;
  List<Map<String, dynamic>> _places = [];
  String? _error, _company;
  bool _enabled = false, _loading = true, _loaded = false, _dirty = false;
  // Last confirmed value; the PWA only follows it after a successful save.
  bool _savedEnabled = false;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    for (final field in _fields) {
      field.addListener(_changed);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  void _changed() {
    if (!_loading && !_dirty && mounted) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    for (final field in _fields) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final c = AppScope.of(context), request = ++_request;
    final company = c.company?.id;
    setState(() {
      _company = company;
      _loading = true;
      _loaded = false;
      _dirty = false;
      _error = null;
      _places = [];
      _point = null;
      _enabled = false;
      for (final field in _fields) {
        field.clear();
      }
    });
    try {
      if ((c.user?.isManager != true ||
              c.user?.canManage('SETTINGS') != true) ||
          company == null) {
        throw const FormatException(
          'Selecione um petshop em que você seja gestor.',
        );
      }
      final policy = await c.bookingPolicy();
      if (!mounted ||
          request != _request ||
          c.company?.id != company ||
          (c.user?.isManager != true ||
              c.user?.canManage('SETTINGS') != true)) {
        return;
      }
      final shop = policy['shop'] as Map?;
      _address.text = shop?['street'] as String? ?? '';
      _district.text = shop?['district'] as String? ?? '';
      _phone.text = displayPhone(shop?['phone'] as String? ?? '');
      _point = shop?['point'] == null
          ? null
          : Map<String, dynamic>.from(shop!['point']);
      for (final (field, key) in [
        (_base, 'baseCents'),
        (_minimum, 'minimumCents'),
        (_perKm, 'perKmCents'),
      ]) {
        field.text = policy[key] == null
            ? ''
            : ((policy[key] as num) / 100)
                  .toStringAsFixed(2)
                  .replaceAll('.', ',');
      }
      _limit.text = '${policy['maxDistanceKm'] ?? 10}';
      _enabled = _savedEnabled = policy['enabled'] == true;
      _loaded = true;
    } catch (e) {
      if (mounted && request == _request) _error = e.toString();
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _searchAddress() async {
    final c = AppScope.of(context), request = _request;
    final company = _company;
    if (!_loaded || _loading || c.catalogOffline || c.company?.id != company) {
      return;
    }
    if (_address.text.trim().length < 5) {
      setState(() => _error = 'Informe o endereço completo e a cidade.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _places = [];
    });
    try {
      final rows = await c.searchBookingAddress(_address.text.trim());
      if (mounted &&
          request == _request &&
          c.company?.id == company &&
          c.user?.isManager == true) {
        setState(() => _places = rows);
      }
    } catch (e) {
      if (mounted && request == _request) setState(() => _error = e.toString());
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  int? _cents(String value) {
    final v = double.tryParse(value.replaceAll(',', '.'));
    return v == null || !v.isFinite ? null : (v * 100).round();
  }

  Future<void> _save() async {
    final c = AppScope.of(context);
    if (!_loaded ||
        _loading ||
        c.busy ||
        c.catalogOffline ||
        (c.user?.isManager != true || c.user?.canManage('SETTINGS') != true) ||
        c.company?.id != _company) {
      return;
    }
    if (_form.currentState?.validate() != true) return;
    if (_point == null) {
      setState(() => _error = 'Localize e selecione o endereço no mapa.');
      return;
    }
    setState(() => _loading = true);
    final success = await c.saveBookingPolicy({
      'enabled': _enabled,
      'shop': {
        'name': c.company!.name,
        'street': _address.text.trim(),
        'district': _district.text.trim(),
        'phone': formatBrazilPhone(_phone.text) ?? _phone.text.trim(),
        'point': _point,
      },
      'baseCents': _cents(_base.text),
      'minimumCents': _cents(_minimum.text),
      'perKmCents': _cents(_perKm.text),
      'maxDistanceKm': int.tryParse(_limit.text),
    });
    if (mounted) {
      setState(() {
        _loading = false;
        _error = success ? null : c.error;
        if (success) {
          _dirty = false;
          _savedEnabled = _enabled;
        }
      });
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configurações de transporte salvas.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    if ((c.user?.isManager != true || c.user?.canManage('SETTINGS') != true) ||
        c.company == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Configurações disponíveis somente ao gestor do petshop selecionado.',
          ),
        ),
      );
    }
    final editable =
        _loaded &&
        !_loading &&
        !c.busy &&
        !c.catalogOffline &&
        c.company?.id == _company;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final discard = await showAppConfirmation(
          context,
          title: 'Descartar alterações não salvas?',
          message:
              'As alterações do transporte serão perdidas. Os tutores continuam vendo a última configuração salva.',
          confirmLabel: 'Descartar e sair',
          cancelLabel: 'Continuar editando',
        );
        if (mounted && discard) {
          setState(() => _dirty = false);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.pop(context);
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Configurações de transporte')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(c.company!.name),
            const TransportOperationsLinks(),
            const SizedBox(height: 16),
            const Text(
              'A taxa por trajeto será o maior valor entre o mínimo e: valor base + distância pelas ruas × valor por km. Coleta e retorno são calculados separadamente. Alterações não mudam pedidos já confirmados.',
            ),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (!_loaded && !_loading)
              OutlinedButton(
                onPressed: c.catalogOffline ? null : _load,
                child: const Text('Tentar novamente'),
              ),
            if (c.catalogOffline)
              const Text(
                'Consulta offline: conecte-se para alterar as configurações.',
              ),
            Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_dirty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppNoticeBanner(
                        background: AppColors.noticeSurface,
                        icon: Icons.info_outline,
                        iconColor: AppColors.warning,
                        title: _enabled == _savedEnabled
                            ? 'Alterações não salvas'
                            : _enabled
                            ? 'Transporte ainda não ativado'
                            : 'Transporte ainda não desativado',
                        message:
                            'O PWA só muda depois de tocar em Salvar taxas e endereço.',
                      ),
                    ),
                  SwitchListTile(
                    title: const Text('Oferecer transporte no PWA'),
                    value: _enabled,
                    onChanged: editable
                        ? (v) => setState(() {
                            _enabled = v;
                            _dirty = true;
                          })
                        : null,
                  ),
                  for (final (field, label) in [
                    (_phone, 'Telefone do petshop'),
                    (_address, 'Endereço completo e cidade'),
                    (_district, 'Bairro e cidade'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        enabled: editable,
                        controller: field,
                        keyboardType: field == _phone
                            ? TextInputType.phone
                            : null,
                        inputFormatters: field == _phone
                            ? const [PhoneInputFormatter()]
                            : null,
                        decoration: InputDecoration(
                          labelText: label,
                          hintText: field == _phone ? phoneHint : null,
                        ),
                        onChanged: field == _address
                            ? (_) => setState(() {
                                _point = null;
                                _places = [];
                              })
                            : null,
                        validator: (v) => field == _phone
                            ? phoneValidator(v)
                            : (v?.trim().length ?? 0) < 1
                            ? 'Preencha este campo'
                            : null,
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: editable ? _searchAddress : null,
                    icon: const Icon(Icons.location_on_outlined),
                    label: const Text('Localizar endereço no mapa'),
                  ),
                  for (final row in _places)
                    ListTile(
                      title: Text(row['label'] as String),
                      onTap: editable
                          ? () => setState(() {
                              _point = Map<String, dynamic>.from(row['point']);
                              _places = [];
                              _dirty = true;
                            })
                          : null,
                    ),
                  if (_point != null)
                    const Text('Endereço no mapa confirmado.'),
                  const SizedBox(height: 16),
                  for (final (field, label) in [
                    (_base, 'Valor base por trajeto (R\$)'),
                    (_perKm, 'Valor por quilômetro (R\$)'),
                    (_minimum, 'Taxa mínima por trajeto (R\$)'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        enabled: editable,
                        controller: field,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(labelText: label),
                        validator: (v) {
                          final n = _cents(v ?? '');
                          return n == null ||
                                  n < 0 ||
                                  n > 100000 ||
                                  field == _perKm && _enabled && n < 1
                              ? 'Informe um valor válido'
                              : null;
                        },
                      ),
                    ),
                  TextFormField(
                    enabled: editable,
                    controller: _limit,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Distância máxima por trajeto (km)',
                    ),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      return n == null || n < 1 || n > 100
                          ? 'Informe de 1 a 100 km'
                          : null;
                    },
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: editable ? _save : null,
                    child: const Text('Salvar taxas e endereço'),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            const SizedBox(height: 12),
            const Text(
              'Busca de endereço © OpenStreetMap contributors. O endereço é enviado ao serviço de mapas apenas ao buscar.',
            ),
          ],
        ),
      ),
    );
  }
}
