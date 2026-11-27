import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppColors;
import 'package:flutter/material.dart';
import '../../state/app_scope.dart';
import '../../core/utils/formatters.dart';
import '../../domain/policies/contact_input.dart';
import '../navigation/tutor_wide_layout.dart';
import 'booking_draft.dart';
import 'confirmation_screen.dart';
import 'widgets/booking_frame.dart';
import '../transport/map_picker_stub.dart'
    if (dart.library.js_interop) '../transport/map_picker_web.dart';

class TransportOptionsScreen extends StatefulWidget {
  const TransportOptionsScreen({
    super.key,
    required this.draft,
    this.appointmentId,
  });
  final BookingDraft draft;

  /// When set, the quote is sent as a request for this existing appointment
  /// instead of continuing a new booking.
  final String? appointmentId;
  @override
  State<TransportOptionsScreen> createState() => _TransportOptionsScreenState();
}

class _TransportOptionsScreenState extends State<TransportOptionsScreen> {
  final _form = GlobalKey<FormState>();
  final _address = TextEditingController(),
      _district = TextEditingController(),
      _name = TextEditingController(),
      _phone = TextEditingController();
  Map<String, dynamic>? _policy, _quote, _point, _center;
  bool _pointFromMap = false;
  List<Map<String, dynamic>> _places = [];
  bool _pickup = false, _return = false, _busy = true;
  String? _error, _company;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    for (final c in [_address, _district, _name, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _sameCompany => AppScope.of(context).companyId == _company;
  Future<void> _load() async {
    final c = AppScope.of(context);
    _company = widget.draft.companyId;
    _name.text = c.tutor?.name ?? '';
    _phone.text = displayPhone(c.tutor?.phone ?? '');
    try {
      final p = await c.transportPolicy();
      if (mounted && _sameCompany) {
        setState(() {
          _policy = p;
          _center = p['shop']?['point'] == null
              ? null
              : Map<String, dynamic>.from(p['shop']['point']);
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _invalidate() {
    _quote = null;
    widget.draft.transportQuote = null;
  }

  Future<void> _search() async {
    if (_address.text.trim().length < 5) return;
    setState(() {
      _busy = true;
      _error = null;
      _places = [];
      _point = null;
      _pointFromMap = false;
      _invalidate();
    });
    try {
      final rows = await AppScope.of(
        context,
      ).searchTransportAddress(_address.text.trim());
      if (mounted && _sameCompany) {
        setState(() {
          _places = rows;
          if (rows.isEmpty) {
            _error =
                'Nenhum endereço encontrado. Complete a busca ou marque no mapa.';
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _calculate() async {
    if (!_form.currentState!.validate()) return;
    if (_point == null) {
      setState(
        () => _error =
            'Selecione o endereço encontrado ou marque o ponto no mapa.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _invalidate();
    });
    try {
      final q = await AppScope.of(context).quoteTransport(_pickup, _return, {
        'name': normalizePersonName(_name.text),
        'phone': formatBrazilPhone(_phone.text) ?? _phone.text.trim(),
        'street': _address.text.trim(),
        'district': _district.text.trim(),
        'point': _point,
      });
      if (mounted && _sameCompany) setState(() => _quote = q);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _request() async {
    final quote = _quote;
    if (!_sameCompany || quote == null) return;
    final controller = AppScope.of(context);
    final sent = await controller.requestTransport(
      widget.appointmentId!,
      quote['id'] as String,
    );
    if (!mounted) return;
    if (sent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pedido de transporte enviado. A equipe confirma o horário.',
          ),
        ),
      );
      Navigator.pop(context);
    } else {
      setState(
        () => _error =
            controller.error ??
            'Não foi possível enviar o pedido. Calcule a taxa novamente.',
      );
    }
  }

  void _continue() {
    if (!_sameCompany) return;
    if ((_pickup || _return) &&
        (_quote == null ||
            DateTime.parse(
              _quote!['expiresAt'] as String,
            ).isBefore(DateTime.now()))) {
      setState(() => _error = 'Calcule novamente a taxa antes de continuar.');
      return;
    }
    if (widget.appointmentId != null) {
      if (!(_pickup || _return)) {
        Navigator.pop(context);
        return;
      }
      _request();
      return;
    }
    widget.draft.transportQuote = _pickup || _return ? _quote : null;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConfirmationScreen(draft: widget.draft),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fromDetail = widget.appointmentId != null;
    final asks = _pickup || _return;
    final button = FilledButton(
      onPressed: _busy || _policy == null ? null : _continue,
      child: Text(
        fromDetail
            ? (asks
                  ? 'Enviar pedido de transporte'
                  : 'Voltar sem pedir transporte')
            : asks
            ? 'Revisar com transporte'
            : 'Vou levar e buscar meus pets',
      ),
    );
    // In the booking it is the fourth of the five steps, as the others: the
    // button goes with the summary on wide windows and in the bar fixed at
    // the bottom of the phone. From the detail of an appointment it ends the
    // page.
    return BookingFrame(
      title: 'Transporte dos pets',
      step: fromDetail ? null : 3,
      stepCount: 5,
      phoneBar: fromDetail ? BookingPhoneBar.inline : BookingPhoneBar.bottom,
      phoneTop: fromDetail ? 20 : 8,
      phoneBottom: fromDetail ? 20 : 24,
      summary: fromDetail ? null : _summary(),
      primary: fromDetail ? null : button,
      back: TextButton(
        onPressed: () => Navigator.maybePop(context),
        child: const Text('Voltar'),
      ),
      children: [
        Text(
          'Como seus pets vão chegar?',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Você pode levá-los ou solicitar coleta e retorno. A equipe confirma a disponibilidade e o horário.',
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_policy != null && _policy!['enabled'] != true)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Esta empresa ainda não oferece transporte pelo aplicativo.',
            ),
          ),
        if (_policy?['enabled'] == true) ...[
          const SizedBox(height: 20),
          ..._options(context),
        ],
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (fromDetail) ...[
          const SizedBox(height: 20),
          // On wide windows, at the right, as the actions of the forms.
          if (tutorWide(context))
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: button,
              ),
            )
          else
            button,
        ],
      ],
    );
  }

  /// What was chosen so far, with the transport as it stands.
  BookingSummary _summary() {
    final draft = widget.draft;
    final at = draft.companyStartsAt ?? draft.startsAt;
    final quote = _pickup || _return ? _quote : null;
    return BookingSummary(
      pets: draft.pets,
      services: draft.selectedServices,
      when: at == null ? null : BookingSummary.day(at, formatTime(at)),
      professional: draft.professionalName ?? 'Qualquer profissional',
      showProfessional: AppScope.of(context).integrated,
      transport: !(_pickup || _return)
          ? 'Você leva e busca os pets'
          : quote == null
          ? 'A calcular'
          : BookingSummary.transportLine(quote),
      transportCents: quote == null ? 0 : (quote['totalCents'] as num).toInt(),
    );
  }

  /// The two options and, when one is chosen, the address and the map. On
  /// the phone, one under the other, as before. On wide windows the map is
  /// taller and, when there is room, beside the address.
  List<Widget> _options(BuildContext context) {
    // The same cards of the services: one under the other on the phone, side
    // by side on wide windows.
    final checks = BookingGrid(
      sameHeight: true,
      children: [
        BookingCheckCard(
          title: 'Buscar meus pets',
          subtitle: 'Do seu endereço até o petshop',
          selected: _pickup,
          onTap: _busy
              ? null
              : () => setState(() {
                  _pickup = !_pickup;
                  _invalidate();
                }),
        ),
        BookingCheckCard(
          title: 'Levar meus pets de volta',
          subtitle: 'Do petshop até o mesmo endereço',
          selected: _return,
          onTap: _busy
              ? null
              : () => setState(() {
                  _return = !_return;
                  _invalidate();
                }),
        ),
      ],
    );
    final asks = _pickup || _return;
    // Taking the pets is a choice of its own, marked while no transport is
    // asked, above the two legs of the transport.
    final own = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BookingCheckCard(
          key: const ValueKey('transport-own'),
          title: 'Levo e busco meus pets',
          subtitle: 'Sem transporte do petshop: é só chegar no horário marcado',
          selected: !asks,
          onTap: _busy
              ? null
              : () => setState(() {
                  _pickup = false;
                  _return = false;
                  _invalidate();
                }),
        ),
        const SizedBox(height: 16),
        Text(
          'Ou peça o transporte do petshop:',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 10),
        checks,
      ],
    );
    if (!tutorWide(context)) {
      return [
        own,
        if (asks) _addressForm([..._fields(), ..._map(320), ..._quoteBlock()]),
      ];
    }
    return [
      LayoutBuilder(
        builder: (context, constraints) {
          if (!asks || constraints.maxWidth < 760) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                own,
                if (asks)
                  _addressForm([..._fields(), ..._map(480), ..._quoteBlock()]),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    own,
                    _addressForm([..._fields(), ..._quoteBlock()]),
                  ],
                ),
              ),
              const SizedBox(width: 28),
              SizedBox(
                width: constraints.maxWidth * 0.42,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _map(480, top: false),
                ),
              ),
            ],
          );
        },
      ),
    ];
  }

  Widget _addressForm(List<Widget> children) => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );

  List<Widget> _fields() => [
    const SizedBox(height: 8),
    Text(
      'Endereço da coleta e do retorno',
      style: Theme.of(context).textTheme.titleMedium,
    ),
    const SizedBox(height: 4),
    Text(
      '1. Escreva a rua, o número e a cidade e toque em Buscar endereço.\n'
      '2. Escolha o endereço encontrado ou marque o ponto no mapa.\n'
      '3. Toque em Calcular taxa de transporte.',
      style: const TextStyle(color: AppColors.muted),
    ),
    const SizedBox(height: 12),
    TextFormField(
      enabled: !_busy,
      controller: _name,
      decoration: const InputDecoration(labelText: 'Responsável no endereço'),
      onChanged: (_) => setState(_invalidate),
      validator: contactNameValidator,
    ),
    const SizedBox(height: 10),
    TextFormField(
      enabled: !_busy,
      controller: _phone,
      decoration: const InputDecoration(
        labelText: 'Telefone de contato',
        hintText: phoneHint,
      ),
      keyboardType: TextInputType.phone,
      inputFormatters: const [PhoneInputFormatter()],
      onChanged: (_) => setState(_invalidate),
      validator: phoneValidator,
    ),
    const SizedBox(height: 10),
    TextFormField(
      enabled: !_busy,
      controller: _address,
      decoration: const InputDecoration(
        labelText: 'Endereço completo, número e cidade',
        helperText: 'Ex.: Rua das Acácias, 245, Cuiabá',
      ),
      onChanged: (_) => setState(() {
        if (!_pointFromMap) _point = null;
        _places = [];
        _invalidate();
      }),
      validator: (v) =>
          (v?.trim().length ?? 0) < 3 ? 'Informe o endereço' : null,
    ),
    const SizedBox(height: 10),
    OutlinedButton.icon(
      onPressed: _busy ? null : _search,
      icon: const Icon(Icons.search),
      label: const Text('Buscar endereço'),
    ),
    for (final result in _places)
      ListTile(
        title: Text(result['label'] as String),
        leading: const Icon(Icons.place_outlined),
        onTap: _busy
            ? null
            : () => setState(() {
                _point = Map<String, dynamic>.from(result['point']);
                _center = _point;
                _pointFromMap = false;
                _places = [];
                _invalidate();
              }),
      ),
    const SizedBox(height: 10),
    TextFormField(
      enabled: !_busy,
      controller: _district,
      decoration: const InputDecoration(
        labelText: 'Bairro e cidade / complemento',
        helperText: 'Ex.: Centro, Cuiabá · apto 12',
      ),
      onChanged: (_) => setState(_invalidate),
      validator: (v) =>
          (v?.trim().isEmpty ?? true) ? 'Informe o bairro/cidade' : null,
    ),
  ];

  /// The map, [height] tall: under the address, or beside it when [top] is
  /// false.
  List<Widget> _map(double height, {bool top = true}) => [
    if (top) const SizedBox(height: 12),
    Text(
      // With a mouse the point is marked with a click.
      '${tutorWide(context) ? 'Ou clique' : 'Ou toque'} no mapa para marcar o ponto. Confira o número e o complemento no endereço ${top ? 'acima' : 'ao lado'}.',
    ),
    const SizedBox(height: 8),
    SizedBox(
      height: height,
      child: MapPicker(
        key: ValueKey(_center.toString()),
        center: _center,
        onSelected: (lat, lng) {
          if (!_busy) {
            setState(() {
              _point = {'lat': lat, 'lng': lng};
              _pointFromMap = true;
              _invalidate();
            });
          }
        },
      ),
    ),
    if (_point != null)
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Ponto selecionado. Confira o endereço antes de calcular.'),
      ),
    const Text(
      'Busca e mapa © OpenStreetMap contributors. O endereço consultado e os pontos da rota são enviados aos serviços de mapas.',
    ),
  ];

  List<Widget> _quoteBlock() => [
    const SizedBox(height: 14),
    Text(
      'Base: ${formatMoney((_policy!['baseCents'] as num) / 100)} · por km: ${formatMoney((_policy!['perKmCents'] as num) / 100)} · mínimo por trajeto: ${formatMoney((_policy!['minimumCents'] as num) / 100)}',
    ),
    const SizedBox(height: 10),
    // A step of the page: the main button of the step stays the one at the
    // bottom.
    OutlinedButton(
      onPressed: _busy ? null : _calculate,
      child: const Text('Calcular taxa de transporte'),
    ),
    if (_quote != null) ...[
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final leg in _quote!['legs'] as List)
                Text(
                  '${leg['type'] == 'PICKUP' ? 'Coleta' : 'Retorno'} · ${formatKm(leg['meters'] as num)} pelas ruas · ${formatMoney(leg['feeCents'] / 100)}',
                ),
              const SizedBox(height: 8),
              Text(
                'Taxa total: ${formatMoney(_quote!['totalCents'] / 100)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Text(
                'Cotação válida por 15 minutos. Transporte sujeito à confirmação da equipe. Sem cobrança automática.',
              ),
            ],
          ),
        ),
      ),
    ],
  ];
}
