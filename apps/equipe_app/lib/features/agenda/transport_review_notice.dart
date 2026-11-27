import 'package:flutter/material.dart';
import '../../domain/models.dart';
import '../../domain/policies/transport_review.dart';
import '../../state/app_scope.dart';
import '../../state/workforce_scope.dart';
import '../navigation/company_view_screen.dart';
import 'transport_management_screen.dart';

/// An in-app alert from authorized online queries. No notification is sent.
class TransportReviewNotice extends StatefulWidget {
  const TransportReviewNotice({
    super.key,
    this.allCompanies = false,
    this.role,
  });
  final bool allCompanies;
  final TenantRole? role;
  @override
  State<TransportReviewNotice> createState() => _TransportReviewNoticeState();
}

class _TransportReviewNoticeState extends State<TransportReviewNotice>
    with WidgetsBindingObserver {
  String? _key;
  int _generation = 0, _count = 0;
  bool _wasBusy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    ++_generation;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _schedule();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final c = AppScope.of(context), scope = WorkforceScope.maybeOf(context);
    final key =
        '${c.sessionRevision}:${c.company?.id}:${widget.allCompanies}:${widget.role}:${scope?.viewRevision}';
    if (_key != key) {
      _count = 0;
      _error = null;
    }
    if (_key != key || _wasBusy && !c.busy) {
      _key = key;
      _schedule();
    }
    _wasBusy = c.busy;
  }

  void _schedule() {
    final generation = ++_generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && generation == _generation) _load(generation);
    });
  }

  Future<void> _load(int generation) async {
    final c = AppScope.of(context), scope = WorkforceScope.maybeOf(context);
    final role = widget.role ?? c.user?.role;
    if (![TenantRole.manager, TenantRole.attendant].contains(role) ||
        c.user == null ||
        !c.supportsTransportReview ||
        c.catalogOffline) {
      if (mounted && generation == _generation) {
        setState(() {
          _count = 0;
          _error = null;
        });
      }
      return;
    }
    int count = 0;
    try {
      if (widget.allCompanies) {
        if (scope?.allCompanies != true) return;
        for (final company in c.companies) {
          if (!company.user.availableRoles.contains(role)) continue;
          String? cursor;
          final cursors = <String>{};
          do {
            final page = await c.companyView(
              tenantId: company.id,
              role: role!,
              resource: 'transports',
              cursor: cursor,
            );
            if (!mounted || generation != _generation) return;
            count += page.items.where((row) {
              final at = transportReviewTime(row['scheduledAt']);
              return at != null &&
                  transportNeedsReview(at, row['status']?.toString() ?? '');
            }).length;
            cursor = page.nextCursor;
            if (cursor != null && !cursors.add(cursor)) {
              throw const FormatException('Página repetida.');
            }
          } while (cursor != null);
        }
      } else {
        final rows = await c.getTransports();
        count = rows
            .where((row) => transportNeedsReview(row.scheduledAt, row.status))
            .length;
      }
      if (mounted && generation == _generation) {
        setState(() {
          _count = count;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _count = 0;
          _error = 'Não foi possível conferir os transportes atrasados.';
        });
      }
    }
  }

  Future<void> _open() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => widget.allCompanies
            ? CompanyViewScreen(
                role: widget.role!,
                resource: 'transports',
                title: 'Transportes para revisão',
                reviewOnly: true,
              )
            : const TransportManagementScreen(reviewOnly: true),
      ),
    );
    if (mounted) _schedule();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    if (_error == null && _count == 0 || c.user == null || c.catalogOffline) {
      return const SizedBox.shrink();
    }
    // Who works in more than one petshop sees which one the alert is about.
    final company = !widget.allCompanies && c.companies.length > 1
        ? c.company?.name
        : null;
    return Card(
      child: TextButton.icon(
        key: const ValueKey('transport-review-notice-action'),
        onPressed: c.busy
            ? null
            : _error == null
            ? _open
            : _schedule,
        icon: Icon(
          _error == null ? Icons.warning_amber_outlined : Icons.refresh,
        ),
        label: Text(
          _error ??
              'Revisar $_count ${_count == 1 ? 'transporte atrasado' : 'transportes atrasados'}${company == null ? '' : ' · $company'}',
        ),
      ),
    );
  }
}
