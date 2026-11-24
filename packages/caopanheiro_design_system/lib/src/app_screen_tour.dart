import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radii.dart';

/// Where the "already seen" marks of the screen tips live. The app decides
/// how it keeps them (on the account, on the server); the screens only ask
/// and report. It notifies when the marks arrive or change.
abstract interface class AppTipsStore implements Listenable {
  /// The tips of [screen] were not yet seen, skipped or turned off.
  bool tipsPending(String screen);

  /// The person reached the end of the tips of [screen] or skipped them.
  void markTipsSeen(String screen);

  /// "Pular tudo": no screen shows its tips again until the person asks.
  void turnOffTips();
}

/// One tip: the [target] it highlights, a title and a text. A tip whose
/// target is not on screen is left out; [AppTourTip.note] has no target and
/// is shown in the middle of the screen.
class AppTourTip {
  const AppTourTip({
    required String this.target,
    required this.title,
    required this.text,
  });
  const AppTourTip.note({required this.title, required this.text})
    : target = null;

  /// Id of an [AppTourTarget].
  final String? target;
  final String title;
  final String text;
}

/// How a tour ended: the last tip, "Pular" (this screen), "Pular tudo"
/// (every screen) or removed by another navigation.
enum AppTourOutcome { finished, skipped, skippedAll, removed }

/// Gives the screens below the [store] of the tips and the targets they
/// point to. Without a scope (or with a null store) no tip is shown.
class AppTipsScope extends StatefulWidget {
  const AppTipsScope({super.key, required this.store, required this.child});
  final AppTipsStore? store;
  final Widget child;

  @override
  State<AppTipsScope> createState() => _AppTipsScopeState();
}

class _AppTipsScopeState extends State<AppTipsScope> {
  final _targets = <String, List<BuildContext>>{};
  bool _tourOpen = false;

  void _add(String id, BuildContext context) =>
      (_targets[id] ??= []).add(context);

  void _remove(String id, BuildContext context) {
    final list = _targets[id];
    if (list == null) return;
    list.remove(context);
    if (list.isEmpty) _targets.remove(id);
  }

  /// The target with this [id] laid out on screen; with several (the items
  /// of a list), the topmost one, then the leftmost.
  BuildContext? _target(String id) {
    BuildContext? best;
    Offset? bestAt;
    for (final context in _targets[id] ?? const <BuildContext>[]) {
      final box = context.findRenderObject();
      // An empty area (a list of actions with none today) counts as absent.
      if (box is! RenderBox ||
          !box.attached ||
          !box.hasSize ||
          box.size.isEmpty) {
        continue;
      }
      final at = box.localToGlobal(Offset.zero);
      if (bestAt == null ||
          at.dy < bestAt.dy ||
          at.dy == bestAt.dy && at.dx < bestAt.dx) {
        best = context;
        bestAt = at;
      }
    }
    return best;
  }

  Rect? _area(String id) {
    final context = _target(id);
    if (context == null) return null;
    final box = context.findRenderObject()! as RenderBox;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// Scrolls the target into the middle of its list when part of it is out
  /// of view, so the highlight never points outside the screen.
  Future<void> _reveal(String id) async {
    final context = _target(id);
    final area = _area(id);
    if (context == null || area == null) return;
    final viewport = Scrollable.maybeOf(context)?.context.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize) return;
    final visible = viewport.localToGlobal(Offset.zero) & viewport.size;
    if (visible.contains(area.topLeft) && visible.contains(area.bottomRight)) {
      return;
    }
    await Scrollable.ensureVisible(context, alignment: 0.5);
    await WidgetsBinding.instance.endOfFrame;
  }

  @override
  Widget build(BuildContext context) =>
      _TipsData(state: this, notifier: widget.store, child: widget.child);
}

class _TipsData extends InheritedNotifier<AppTipsStore> {
  const _TipsData({
    required this.state,
    required super.notifier,
    required super.child,
  });
  final _AppTipsScopeState state;
}

/// Tells the screen tips below whether this part of the screen is the one
/// being shown, such as the selected tab of an [IndexedStack].
class AppTipsVisibility extends InheritedWidget {
  const AppTipsVisibility({
    super.key,
    required this.visible,
    required super.child,
  });
  final bool visible;

  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AppTipsVisibility>()
          ?.visible ??
      true;

  @override
  bool updateShouldNotify(AppTipsVisibility old) => old.visible != visible;
}

/// Marks [child] as the area a tip with this [id] highlights.
class AppTourTarget extends StatefulWidget {
  const AppTourTarget({super.key, required this.id, required this.child});
  final String id;
  final Widget child;

  @override
  State<AppTourTarget> createState() => _AppTourTargetState();
}

class _AppTourTargetState extends State<AppTourTarget> {
  _AppTipsScopeState? _scope;
  String? _id;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _register();
  }

  @override
  void didUpdateWidget(AppTourTarget old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) _register();
  }

  void _register() {
    final scope = context.getInheritedWidgetOfExactType<_TipsData>()?.state;
    if (scope == _scope && _id == widget.id) return;
    if (_id != null) _scope?._remove(_id!, context);
    _scope = scope;
    _id = widget.id;
    scope?._add(widget.id, context);
  }

  @override
  void dispose() {
    if (_id != null) _scope?._remove(_id!, context);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Shows the [tips] of [screen] over it the first time the person sees it:
/// when the store says they are pending, the screen is [ready] (loaded),
/// visible and on top. Finishing or "Pular" marks this screen as seen;
/// "Pular tudo" turns every tip off.
class AppScreenTips extends StatefulWidget {
  const AppScreenTips({
    super.key,
    required this.screen,
    required this.tips,
    this.ready = true,
    required this.child,
  });
  final String screen;
  final List<AppTourTip> tips;
  final bool ready;
  final Widget child;

  @override
  State<AppScreenTips> createState() => _AppScreenTipsState();
}

class _AppScreenTipsState extends State<AppScreenTips> {
  bool _scheduled = false, _handled = false;
  Animation<double>? _waiting;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Depends on the store and on the visibility: both bring a new check.
    final store = context
        .dependOnInheritedWidgetOfExactType<_TipsData>()
        ?.notifier;
    // Once the marks say this screen is done, a later "Rever dicas" (marks
    // erased) shows the tips again, even on a screen that stayed mounted.
    if (_handled && store?.tipsPending(widget.screen) == false) {
      _handled = false;
    }
    AppTipsVisibility.of(context);
    _schedule();
  }

  @override
  void didUpdateWidget(AppScreenTips old) {
    super.didUpdateWidget(old);
    if (old.screen != widget.screen) _handled = false;
    _schedule();
  }

  @override
  void dispose() {
    _waiting?.removeStatusListener(_routeSettled);
    super.dispose();
  }

  void _schedule() {
    if (_scheduled || _handled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      _maybeShow();
    });
  }

  void _routeSettled(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _waiting?.removeStatusListener(_routeSettled);
    _waiting = null;
    if (mounted) _schedule();
  }

  Future<void> _maybeShow() async {
    if (!mounted || _handled || !widget.ready) return;
    final data = context.getInheritedWidgetOfExactType<_TipsData>();
    final store = data?.notifier;
    if (data == null || store == null || data.state._tourOpen) return;
    if (!store.tipsPending(widget.screen) || !AppTipsVisibility.of(context)) {
      return;
    }
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    final animation = route?.animation;
    if (animation != null && animation.status != AnimationStatus.completed) {
      if (_waiting == null) {
        _waiting = animation..addStatusListener(_routeSettled);
      }
      return;
    }
    final scope = data.state;
    final steps = [
      for (final tip in widget.tips)
        if (tip.target == null || scope._area(tip.target!) != null)
          _Step(
            locate: tip.target == null
                ? () => null
                : () => scope._area(tip.target!),
            reveal: tip.target == null
                ? () async {}
                : () => scope._reveal(tip.target!),
            title: tip.title,
            text: tip.text,
          ),
    ];
    // Nothing of this screen on view yet (still loading): try again later.
    if (steps.isEmpty) return;
    _handled = true;
    scope._tourOpen = true;
    final AppTourOutcome outcome;
    try {
      outcome = await _showTour(context, steps);
    } finally {
      scope._tourOpen = false;
    }
    switch (outcome) {
      case AppTourOutcome.finished || AppTourOutcome.skipped:
        store.markTipsSeen(widget.screen);
      case AppTourOutcome.skippedAll:
        store.turnOffTips();
      case AppTourOutcome.removed:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _Step {
  const _Step({
    required this.locate,
    required this.reveal,
    required this.title,
    required this.text,
  });
  final Rect? Function() locate;
  final Future<void> Function() reveal;
  final String title;
  final String text;
}

Future<AppTourOutcome> _showTour(
  BuildContext context,
  List<_Step> steps,
) async {
  if (steps.isEmpty) return AppTourOutcome.finished;
  // The root navigator covers the whole window: a screen inside an inner
  // navigator (beside a side bar) still gets the cut-out where its target
  // is, because the targets are measured on the whole window.
  final result = await Navigator.of(context, rootNavigator: true)
      .push<AppTourOutcome>(
        PageRouteBuilder<AppTourOutcome>(
          opaque: false,
          transitionDuration: const Duration(milliseconds: 200),
          reverseTransitionDuration: const Duration(milliseconds: 150),
          pageBuilder: (route, animation, _) => FadeTransition(
            opacity: animation,
            child: _ScreenTour(
              steps: steps,
              onDone: (outcome) => Navigator.of(route).pop(outcome),
            ),
          ),
        ),
      );
  return result ?? AppTourOutcome.removed;
}

/// Dimmed screen with the target cut out and a balloon with the tip,
/// "Dica x de n", "Pular", "Próximo" ("Concluir" on the last one) and
/// "Pular tudo". The system back counts as "Pular".
class _ScreenTour extends StatefulWidget {
  const _ScreenTour({required this.steps, required this.onDone});
  final List<_Step> steps;
  final ValueChanged<AppTourOutcome> onDone;

  @override
  State<_ScreenTour> createState() => _ScreenTourState();
}

class _ScreenTourState extends State<_ScreenTour> {
  int _index = 0;
  bool _done = false;

  bool get _last => _index >= widget.steps.length - 1;

  @override
  void initState() {
    super.initState();
    _reveal();
  }

  /// Brings the target of the current tip into view, then measures again.
  Future<void> _reveal() async {
    await widget.steps[_index].reveal();
    if (mounted) setState(() {});
  }

  void _finish(AppTourOutcome outcome) {
    if (_done) return;
    _done = true;
    widget.onDone(outcome);
  }

  void _next() {
    if (_last) return _finish(AppTourOutcome.finished);
    setState(() => _index++);
    _reveal();
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_index];
    final padding = MediaQuery.paddingOf(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish(AppTourOutcome.skipped);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final area = step.locate();
          final hole = area == null
              ? null
              : RRect.fromRectAndRadius(
                  area.inflate(6),
                  const Radius.circular(16),
                );
          final width = math.min(size.width - 32, 360.0);
          final below = hole != null && hole.center.dy < size.height / 2;
          final left = hole == null
              ? (size.width - width) / 2
              : (hole.center.dx - width / 2)
                    .clamp(16.0, math.max(16.0, size.width - 16 - width))
                    .toDouble();
          final balloon = _Balloon(
            key: ValueKey(_index),
            index: _index,
            count: widget.steps.length,
            title: step.title,
            text: step.text,
            last: _last,
            onNext: _next,
            onSkip: () => _finish(AppTourOutcome.skipped),
            onSkipAll: () => _finish(AppTourOutcome.skippedAll),
            arrowX: hole == null
                ? null
                : (hole.center.dx - left).clamp(27.0, width - 27).toDouble(),
            arrowUp: below,
          );
          return Stack(
            children: [
              // Taps outside the balloon never reach the screen below.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: CustomPaint(painter: _ScrimPainter(hole)),
                ),
              ),
              if (hole == null)
                Positioned(
                  left: left,
                  width: width,
                  top: padding.top + 16,
                  bottom: padding.bottom + 16,
                  child: Center(child: balloon),
                )
              else if (below)
                Positioned(
                  left: left,
                  width: width,
                  top: hole.bottom + 4,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: math.max(
                        180,
                        size.height - hole.bottom - padding.bottom - 20,
                      ),
                    ),
                    child: balloon,
                  ),
                )
              else
                Positioned(
                  left: left,
                  width: width,
                  bottom: size.height - hole.top + 4,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: math.max(180, hole.top - padding.top - 20),
                    ),
                    child: balloon,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Balloon extends StatelessWidget {
  const _Balloon({
    super.key,
    required this.index,
    required this.count,
    required this.title,
    required this.text,
    required this.last,
    required this.onNext,
    required this.onSkip,
    required this.onSkipAll,
    required this.arrowX,
    required this.arrowUp,
  });
  final int index, count;
  final String title, text;
  final bool last;
  final VoidCallback onNext, onSkip, onSkipAll;
  final double? arrowX;
  final bool arrowUp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final stacked = MediaQuery.textScalerOf(context).scale(15) > 20;
    const compact = Size(0, 44);
    final next = FilledButton(
      style: FilledButton.styleFrom(minimumSize: compact),
      onPressed: onNext,
      child: Text(last ? 'Concluir' : 'Próximo'),
    );
    final skip = OutlinedButton(
      style: OutlinedButton.styleFrom(minimumSize: compact),
      onPressed: onSkip,
      child: const Text('Pular'),
    );
    final skipAll = TextButton(
      style: TextButton.styleFrom(
        minimumSize: compact,
        foregroundColor: AppColors.muted,
      ),
      onPressed: onSkipAll,
      child: const Text('Pular tudo'),
    );
    // The text scrolls when space is short; the buttons always stay in view.
    final card = Material(
      color: AppColors.paper,
      elevation: 6,
      borderRadius: AppRadii.card,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Dica ${index + 1} de $count',
                      style: theme.bodySmall?.copyWith(color: AppColors.muted),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: theme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(text, style: theme.bodyMedium),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (last)
              next
            else if (stacked) ...[
              next,
              const SizedBox(height: 8),
              skip,
            ] else
              Row(
                children: [
                  Expanded(child: skip),
                  const SizedBox(width: 10),
                  Expanded(child: next),
                ],
              ),
            const SizedBox(height: 2),
            skipAll,
          ],
        ),
      ),
    );
    final arrow = arrowX == null
        ? null
        : Padding(
            padding: EdgeInsets.only(left: arrowX! - 9),
            child: CustomPaint(
              size: const Size(18, 9),
              painter: _ArrowPainter(up: arrowUp),
            ),
          );
    return Semantics(
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (arrow != null && arrowUp) arrow,
          Flexible(child: card),
          if (arrow != null && !arrowUp) arrow,
        ],
      ),
    );
  }
}

class _ScrimPainter extends CustomPainter {
  const _ScrimPainter(this.hole);
  final RRect? hole;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);
    if (hole != null) path.addRRect(hole!);
    canvas.drawPath(
      path,
      Paint()..color = AppColors.navy.withValues(alpha: 0.78),
    );
    if (hole != null) {
      canvas.drawRRect(
        hole!,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppColors.paper,
      );
    }
  }

  @override
  bool shouldRepaint(_ScrimPainter old) => old.hole != hole;
}

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter({required this.up});
  final bool up;

  @override
  void paint(Canvas canvas, Size size) {
    final path = up
        ? (Path()
            ..moveTo(0, size.height)
            ..lineTo(size.width / 2, 0)
            ..lineTo(size.width, size.height))
        : (Path()
            ..moveTo(0, 0)
            ..lineTo(size.width / 2, size.height)
            ..lineTo(size.width, 0));
    canvas.drawPath(path..close(), Paint()..color = AppColors.paper);
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => old.up != up;
}
