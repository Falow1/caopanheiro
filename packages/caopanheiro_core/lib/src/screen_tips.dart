/// Marks of the screen tips kept in the account on the server
/// (users/{uid}.screenTips): the screens already seen or skipped, and
/// whether the person turned every tip off with "Pular tudo".
class ScreenTips {
  const ScreenTips({this.seen = const {}, this.off = false});

  /// Null when the server did not send the marks: then no tip is offered.
  static ScreenTips? fromJson(Object? value) {
    if (value is! Map) return null;
    final seen = value['seen'];
    return ScreenTips(
      seen: seen is List ? seen.whereType<String>().toSet() : const {},
      off: value['off'] == true,
    );
  }

  final Set<String> seen;
  final bool off;

  bool pending(String screen) => !off && !seen.contains(screen);
  ScreenTips markSeen(String screen) =>
      ScreenTips(seen: {...seen, screen}, off: off);
  ScreenTips turnOff() => ScreenTips(seen: seen, off: true);
}

/// Optional capability of a repository that reaches the account on the
/// server. Each write changes [screenTips] at once; a failed write only
/// brings the tips back on the next access.
abstract interface class ScreenTipsRepository {
  ScreenTips? get screenTips;
  Future<void> markScreenTipsSeen(String screen);
  Future<void> turnOffScreenTips();

  /// "Rever dicas": every screen shows its tips again.
  Future<void> resetScreenTips();
}
