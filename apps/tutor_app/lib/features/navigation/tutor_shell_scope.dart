import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppDimensions, AppWindowClass, appWindowClassOf;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Marks the screens of a booking (new or reschedule): leaving them from the
/// side bar asks first, because the choices are lost.
const bookingRoute = RouteSettings(name: 'tutor.booking');

/// Marks the screens after a booking was confirmed: nothing is lost anymore,
/// so leaving them never asks.
const bookingDoneRoute = RouteSettings(name: 'tutor.booking.done');

/// What the screens inside the Tutor shell can ask of it. Inner screens open
/// in the content area, next to the side bar on wide windows, so going back
/// to the tabs goes through the shell instead of replacing the whole window.
abstract interface class TutorShell {
  /// Index of the selected tab: 0 Início, 1 Agendar, 2 Pets, 3 Perfil.
  ValueListenable<int> get tab;

  /// True while a screen of a booking is open in the content area.
  ValueListenable<bool> get bookingOpen;

  /// Closes the inner screens (asking first when something would be lost)
  /// and shows [index].
  Future<void> selectTab(int index);

  /// Starts a new booking from the tabs, closing the inner screens first.
  Future<void> openBooking();

  /// Closes every inner screen without asking and shows [tab].
  void backToTabs({int tab = 0});

  /// Same refresh as pulling the page down.
  Future<void> refresh();

  /// Opens the dialog that links another petshop.
  Future<void> linkCompany();
}

/// Gives the screens of the content area their [TutorShell].
class TutorShellScope extends InheritedWidget {
  const TutorShellScope({super.key, required this.shell, required super.child});
  final TutorShell shell;

  /// The shell around [context], or null for screens shown outside it
  /// (tests and the sign-in flow).
  static TutorShell? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TutorShellScope>()?.shell;

  @override
  bool updateShouldNotify(TutorShellScope oldWidget) =>
      shell != oldWidget.shell;
}

/// Width left for the screen at [context]: the window, minus the side bar
/// when the shell shows it (wide windows).
double tutorContentWidth(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  final beside =
      TutorShellScope.maybeOf(context) != null &&
      appWindowClassOf(context) == AppWindowClass.expanded;
  return beside ? width - AppDimensions.tutorSideBarWidth : width;
}
