import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

/// One in-app notice. Notices are read when the app opens or refreshes; they
/// are not push notifications and are not delivered outside the application.
class AppNotice {
  const AppNotice({
    required this.id,
    required this.title,
    required this.text,
    required this.createdAt,
    this.type = '',
    this.unread = false,
    this.appointmentId,
    this.transportId,
    this.supportRequestId,
  });

  factory AppNotice.fromJson(Map<String, dynamic> value) => AppNotice(
    id: value['id'] as String,
    title: value['title'] as String? ?? '',
    text: value['text'] as String? ?? '',
    createdAt:
        DateTime.tryParse(value['createdAt'] as String? ?? '')?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0),
    type: value['type'] as String? ?? '',
    unread: value['unread'] == true,
    appointmentId: value['appointmentId'] as String?,
    transportId: value['transportId'] as String?,
    supportRequestId: value['supportRequestId'] as String?,
  );

  final String id;
  final String title;
  final String text;
  final DateTime createdAt;
  final String type;
  final bool unread;
  final String? appointmentId;
  final String? transportId;
  final String? supportRequestId;
}

/// Bell with the number of unread notices. The count is supplied by the app.
class AppNoticeBell extends StatelessWidget {
  const AppNoticeBell({super.key, required this.unread, this.onPressed});

  final int unread;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: unread > 0 ? 'Avisos, $unread não lidos' : 'Avisos',
    onPressed: onPressed,
    icon: Badge(
      isLabelVisible: unread > 0,
      backgroundColor: AppColors.orange,
      label: Text(unread > 99 ? '99+' : '$unread'),
      child: const Icon(Icons.notifications_outlined),
    ),
  );
}

/// List of notices with loading, empty and error states. Loading and marking
/// as seen are callbacks: this package holds no data access.
class AppNoticesScreen extends StatefulWidget {
  const AppNoticesScreen({
    super.key,
    required this.load,
    this.onSeen,
    this.onOpen,
    this.maxWidth,
    this.cardGap = 0,
  });

  final Future<List<AppNotice>> Function() load;
  final Future<void> Function()? onSeen;
  final void Function(AppNotice notice)? onOpen;

  /// Width of the list's column, centered, on wide windows. Null keeps the
  /// whole width. The list still scrolls from anywhere on the page.
  final double? maxWidth;

  /// Space between two notices. Zero keeps the cards touching, as the
  /// Equipe shows them.
  final double cardGap;

  @override
  State<AppNoticesScreen> createState() => _AppNoticesScreenState();
}

class _AppNoticesScreenState extends State<AppNoticesScreen> {
  List<AppNotice>? _items;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final items = await widget.load();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
      // Seen only after the list was really shown to the person.
      await widget.onSeen?.call();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
  static String formatMoment(DateTime moment) =>
      '${_two(moment.day)}/${_two(moment.month)} às ${_two(moment.hour)}:${_two(moment.minute)}';

  @override
  Widget build(BuildContext context) {
    final items = _items ?? const <AppNotice>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Avisos')),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: LayoutBuilder(
            builder: (context, constraints) => _list(constraints, items),
          ),
        ),
      ),
    );
  }

  Widget _list(BoxConstraints constraints, List<AppNotice> items) {
    final maxWidth = widget.maxWidth;
    final side = maxWidth == null
        ? 0.0
        : math.max(0.0, (constraints.maxWidth - maxWidth) / 2);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20 + side, 12, 20 + side, 28),
      children: [
        const Text(
          'Os avisos aparecem ao abrir ou atualizar o aplicativo. Não são notificações enviadas ao celular.',
          style: AppTextStyles.captionMuted,
        ),
        const SizedBox(height: 14),
        if (_loading && _items == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_failed && _items == null) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Não foi possível carregar os avisos. Confira a conexão.',
              textAlign: TextAlign.center,
            ),
          ),
          OutlinedButton(
            onPressed: _load,
            child: const Text('Tentar novamente'),
          ),
        ] else if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Text(
              'Nenhum aviso por enquanto.',
              textAlign: TextAlign.center,
            ),
          )
        else
          for (final (index, notice) in items.indexed)
            Padding(
              padding: EdgeInsets.only(top: index == 0 ? 0 : widget.cardGap),
              child: _NoticeCard(
                notice: notice,
                onTap: widget.onOpen == null
                    ? null
                    : () => widget.onOpen!(notice),
              ),
            ),
        if (_failed && _items != null)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'Não foi possível atualizar agora. A lista pode estar desatualizada.',
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.notice, this.onTap});

  final AppNotice notice;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Icon(
        notice.unread
            ? Icons.notifications_active_rounded
            : Icons.notifications_none_rounded,
        color: notice.unread ? AppColors.orange : AppColors.muted,
        semanticLabel: notice.unread ? 'Não lido' : 'Lido',
      ),
      title: Text(
        notice.title,
        style: notice.unread ? AppTextStyles.strong : null,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (notice.text.isNotEmpty) Text(notice.text),
          const SizedBox(height: 4),
          Text(
            _AppNoticesScreenState.formatMoment(notice.createdAt),
            style: AppTextStyles.metadata,
          ),
        ],
      ),
    ),
  );
}
