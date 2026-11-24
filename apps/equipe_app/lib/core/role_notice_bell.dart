import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppNotice, AppNoticeBell, AppNoticesScreen;
import 'package:flutter/material.dart';

import '../domain/repositories/team_extras_repository.dart';

/// Bell of one area (gestão/atendimento, profissional or entregador) in one
/// petshop. The count is read when the area opens, when [refreshKey] changes
/// and after the list is closed. A failed read only hides the count.
class RoleNoticeBell extends StatefulWidget {
  const RoleNoticeBell({
    super.key,
    required this.source,
    required this.tenantId,
    this.refreshKey,
  });

  final RoleNoticesSource? source;
  final String? tenantId;
  final Object? refreshKey;

  @override
  State<RoleNoticeBell> createState() => _RoleNoticeBellState();
}

class _RoleNoticeBellState extends State<RoleNoticeBell> {
  int _unread = 0;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _count();
  }

  @override
  void didUpdateWidget(RoleNoticeBell old) {
    super.didUpdateWidget(old);
    if (old.tenantId != widget.tenantId ||
        old.refreshKey != widget.refreshKey ||
        !identical(old.source, widget.source)) {
      if (old.tenantId != widget.tenantId) _unread = 0;
      _count();
    }
  }

  Future<void> _count() async {
    final source = widget.source, tenant = widget.tenantId;
    final request = ++_request;
    if (source == null || tenant == null) return;
    try {
      final page = await source.roleNotices(tenant);
      if (!mounted || request != _request) return;
      setState(() => _unread = (page['unread'] as num?)?.toInt() ?? 0);
    } catch (_) {
      // Offline or access being revalidated: the bell stays without a count.
    }
  }

  Future<List<AppNotice>> _load(RoleNoticesSource source, String tenant) async {
    final page = await source.roleNotices(tenant);
    return ((page['items'] as List?) ?? const [])
        .map(
          (item) => AppNotice.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.source, tenant = widget.tenantId;
    if (source == null || tenant == null) return const SizedBox.shrink();
    return AppNoticeBell(
      unread: _unread,
      onPressed: () async {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AppNoticesScreen(
              load: () => _load(source, tenant),
              onSeen: () => source.markRoleNoticesSeen(tenant),
            ),
          ),
        );
        if (mounted) _count();
      },
    );
  }
}
