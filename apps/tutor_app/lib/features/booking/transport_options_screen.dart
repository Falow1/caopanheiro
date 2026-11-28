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
import '../transport/address_editor.dart';

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
  final _name = TextEditingController(), _phone = TextEditingController();
  // The address and its point; it starts with the one kept in the account.
  AddressEditingController? _address;
  int _addressRevision = 0;
  Map<String, dynamic>? _policy, _quote, _center;
  bool _pickup = false, _return = false, _busy = true;

  /// Keeps the address in the account for the next requests.
  bool _remember = true;
  String? _error, _company, _rememberNote;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_address != null) return;
    final saved = AppScope.of(context).savedAddress;
    final address = AddressEditingController(
      initial: saved,
      search: (query) => AppScope.of(context).searchTransportAddress(query),
      reverse: AppScope.of(context).addressAvailable
          ? (lat, lng) => AppScope.of(context).reverseAddress(lat, lng)
          : null,
    );
    _address = address;
    _addressRevision = address.revision;
    address.addListener(() {
      if (!mounted) return;
      setState(() {
        if (address.revision != _addressRevision) {
          _addressRevision = address.revision;
          _invalidate();
          _error = null;
        }
      });
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _phone]) {
      c.dispose();
    }
    _address?.dispose();
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
          _remember = c.addressAvailable;
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

  void _showError(String message) {
    setState(() => _error = message);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _calculate() async {
    if (!_form.currentState!.validate()) {
      _showError('Confira os campos obrigatórios do endereço e do contato.');
      return;
    }
    final address = _address!.value;
    if (address == null) {
      _showError(
        'Selecione o endereço encontrado, use a sua localização ou marque o ponto no mapa.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _rememberNote = null;
      _invalidate();
    });
    final controller = AppScope.of(context);
    try {
      final q = await controller.quoteTransport(_pickup, _return, {
        'name': normalizePersonName(_name.text),
        'phone': formatBrazilPhone(_phone.text) ?? _phone.text.trim(),
        'street': address.street,
        'district': address.district,
        'point': address.point,
      });
      if (mounted && _sameCompany) setState(() => _quote = q);
      // The address the route accepted is kept for the next requests.
      if (_remember && controller.savedAddress != address) {
        try {
          await controller.saveAddress(address);
          if (mounted) {
            setState(
              () => _rememberNote =
                  'Endereço guardado na sua conta para os próximos pedidos.',
            );
          }
        } catch (_) {
          if (mounted) {
            setState(
              () => _rememberNote =
                  'Não foi possível guardar o endereço na sua conta; ele vale para este pedido.',
            );
          }
        }
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
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
    if ((_pickup || _return) && !_hasCurrentQuote) {
      _calculate();
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

  bool get _hasCurrentQuote {
    final expiration = _quote?['expiresAt'];
    return expiration is String &&
        (DateTime.tryParse(expiration)?.isAfter(DateTime.now()) ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final fromDetail = widget.appointmentId != null;
    final asks = _pickup || _return;
    final needsQuote = asks && !_hasCurrentQuote;
    final button = FilledButton(
      onPressed: _busy || _policy == null || (asks && _address!.busy)
          ? null
          : _continue,
      child: Text(
        needsQuote
            ? 'Calcular taxa de transporte'
            : fromDetail
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
      professional: draft.professionalLabel,
      showProfessional: AppScope.of(context).integrated,
      petProfessionals: draft.pets.length > 1 ? draft.petProfessionals : null,
      reservedMinutes: draft.scheduleMinutes,
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
      AppScope.of(context).savedAddress == null
          ? '1. Escreva o endereço e toque em Buscar endereço, use a sua localização ou marque o ponto no mapa.\n'
                '2. Confira a rua, o número e o bairro.\n'
                '3. Toque em Calcular taxa de transporte.'
          : 'Este é o endereço guardado na sua conta. Corrija se precisar e toque em Calcular taxa de transporte.',
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
    AddressFields(controller: _address!, enabled: !_busy),
    if (AppScope.of(context).addressAvailable)
      CheckboxListTile(
        key: const ValueKey('transport-remember-address'),
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: _remember,
        onChanged: _busy ? null : (v) => setState(() => _remember = v == true),
        title: const Text(
          'Guardar este endereço na minha conta para os próximos pedidos',
        ),
      ),
  ];

  /// The map, [height] tall: under the address, or beside it when [top] is
  /// false.
  List<Widget> _map(double height, {bool top = true}) => [
    AddressMap(
      controller: _address!,
      height: height,
      center: _center,
      top: top,
      enabled: !_busy,
    ),
  ];

  List<Widget> _quoteBlock() => [
    const SizedBox(height: 14),
    Text(
      'Base: ${formatMoney((_policy!['baseCents'] as num) / 100)} · por km: ${formatMoney((_policy!['perKmCents'] as num) / 100)} · mínimo por trajeto: ${formatMoney((_policy!['minimumCents'] as num) / 100)}',
    ),
    if (_rememberNote case final note?)
      Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(note, style: const TextStyle(color: AppColors.muted)),
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
