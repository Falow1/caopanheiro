import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppContentCard, AppScreenTips, AppTextStyles;
import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/live_screen_reload.dart';
import '../../core/screen_tips.dart';
import '../../core/widgets.dart';
import '../../state/app_scope.dart';
import 'billing_models.dart';
import 'billing_view.dart';
import 'company_extras.dart';

/// Plan and subscription. The principal manager sees the subscription that
/// covers all their petshops and asks for changes (A1); anyone else, or a
/// legacy petshop, sees the plan of the selected petshop for consultation.
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});
  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> with LiveScreenReload {
  CompanyPlanInfo? _plan;
  BillingOverview? _billing;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void liveScreenReload() {
    if (!_loading) _load(quiet: true);
  }

  /// [quiet]: live refresh, without loading state; a failure keeps the plan
  /// shown and waits for the next change or a manual retry.
  Future<void> _load({bool quiet = false}) async {
    if (quiet) {
      try {
        await _read();
      } catch (_) {}
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _read();
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Não foi possível consultar o plano. Confira a conexão.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// The subscription of the account first; without one (or on a server
  /// before the A1), the plan of the selected petshop.
  Future<void> _read() async {
    final controller = AppScope.of(context);
    BillingOverview? billing;
    try {
      billing = await controller.loadBillingOverview();
    } catch (_) {
      // The plan of the petshop answers for itself, including its failure.
      billing = null;
    }
    if (billing != null) {
      if (mounted) setState(() => _billing = billing);
      await controller.refreshCompanyEntitlements();
      return;
    }
    final plan = await controller.loadCompanyPlan();
    if (mounted) {
      setState(() {
        _billing = null;
        _plan = plan;
      });
    }
  }

  static String _usage(int used, int? limit) =>
      limit == null ? '$used em uso' : '$used de $limit em uso';

  @override
  Widget build(BuildContext context) {
    final billing = _billing;
    if (billing != null) {
      return AppScreenTips(
        screen: TipScreens.plan,
        tips: TeamTips.plan,
        child: Scaffold(
          appBar: AppBar(title: const Text('Plano e assinatura')),
          body: PageBody(
            child: BillingView(
              overview: billing,
              onDone: () => _load(quiet: true),
            ),
          ),
        ),
      );
    }
    final plan = _plan;
    return Scaffold(
      appBar: AppBar(title: const Text('Plano e assinatura')),
      body: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_loading && plan == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_error != null) ...[
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _loading ? null : _load,
                child: const Text('Tentar novamente'),
              ),
            ],
            if (plan != null) ...[
              Text(
                plan.hasPlan ? plan.planName : 'Plano não informado',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              if (plan.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(plan.description),
              ],
              const SizedBox(height: 20),
              AppContentCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Line('Assinatura', plan.statusLabel),
                    if (plan.renewsAt != null)
                      _Line(
                        plan.subscriptionStatus == 'TRIAL'
                            ? 'Teste até'
                            : 'Renovação',
                        date(plan.renewsAt!),
                      ),
                    if (plan.monthlyPriceCents != null)
                      _Line(
                        'Valor mensal',
                        money(plan.monthlyPriceCents! / 100),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const SectionTitle('Limites do plano'),
              const SizedBox(height: 10),
              AppContentCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Line('Usuários', _usage(plan.usedUsers, plan.maxUsers)),
                    _Line(
                      'Profissionais',
                      _usage(plan.usedProfessionals, plan.maxProfessionals),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Convites ainda não aceitos também ocupam vaga de usuário.',
                style: AppTextStyles.captionMuted,
              ),
              if (plan.features.isNotEmpty) ...[
                const SizedBox(height: 20),
                const SectionTitle('Incluído no plano'),
                const SizedBox(height: 10),
                for (final feature in plan.features)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_rounded, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(feature)),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 20),
              const Text(
                'A troca de plano e a situação da assinatura são definidas pela administração da plataforma. Para pedir uma mudança, use Suporte da plataforma.',
                style: AppTextStyles.captionMuted,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: AppTextStyles.captionMuted)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: AppTextStyles.strong,
          ),
        ),
      ],
    ),
  );
}
