import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:caopanheiro_core/caopanheiro_core.dart' show NetworkProblem;
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppScreenTips, AppTourTarget;
import '../../core/screen_tips.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show
        AppNoticeBanner,
        AppRadii,
        AppOfflineBanner,
        AppPawMark,
        AppRefreshBody,
        AppWindowClass,
        appWindowClassOf;

import '../../core/theme/app_theme.dart';
import '../../core/widgets/confirm_dialogs.dart';
import '../../state/app_scope.dart';
import '../auth/login_screen.dart';
import '../auth/account_contact_screen.dart';
import '../auth/company_access_screen.dart';

import '../booking/pet_selection_screen.dart';
import '../home/home_screen.dart';
import '../home/read_only_company.dart';
import '../pets/pets_screen.dart';
import '../profile/profile_screen.dart';
import 'booking_landing_wide.dart';
import 'tutor_shell_scope.dart';
import 'tutor_side_bar.dart';

/// Closes the booking and shows Início: inside the shell, its inner screens
/// close; elsewhere a new shell replaces the whole window.
void backToHome(BuildContext context) {
  final shell = TutorShellScope.maybeOf(context);
  if (shell != null) return shell.backToTabs();
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const MainShell()),
    (_) => false,
  );
}

/// The signed-in Tutor: the four tabs and the screens opened from them.
/// Those screens open in a navigator of the content area. On wide windows
/// the [TutorSideBar] stays beside them; on narrow ones they cover the
/// bottom bar, as on a phone. Changing the window width changes only this
/// frame: the open screens, their state and the typed text stay.
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialIndex = 0});
  final int initialIndex;
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with WidgetsBindingObserver
    implements TutorShell {
  final _content = GlobalKey<NavigatorState>();
  late final _routes = _RouteTracker(_routesChanged);
  @override
  late final ValueNotifier<int> tab = ValueNotifier(widget.initialIndex);
  @override
  final ValueNotifier<bool> bookingOpen = ValueNotifier(false);

  /// Whether the content navigator was built and its first focus checked.
  bool _contentShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    tab.dispose();
    bookingOpen.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  @override
  Future<void> refresh() async {
    final controller = AppScope.of(context);
    await controller.refresh();
    if (mounted && controller.tutor == null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Future<void> linkCompany() async {
    final code = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vincular outro petshop'),
        content: TextField(
          controller: code,
          decoration: const InputDecoration(
            labelText: 'Link ou código do convite',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, code.text),
            child: const Text('Vincular'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (value != null) await AppScope.of(context).acceptLink(value);
    // Dialog route owns the field until its closing animation has finished.
    Future<void>.delayed(const Duration(milliseconds: 300), code.dispose);
  }

  @override
  Future<void> selectTab(int index) async {
    if (await _closeInnerScreens()) tab.value = index;
  }

  @override
  Future<void> openBooking() async {
    if (AppScope.of(context).companyReadOnly) {
      await showReadOnlyCompany(context);
      return;
    }
    if (AppScope.of(context).companyBookingPaused) {
      await showBookingByPhone(context);
      return;
    }
    if (!await _closeInnerScreens()) return;
    _content.currentState?.push(
      MaterialPageRoute<void>(
        settings: bookingRoute,
        builder: (_) => const PetSelectionScreen(),
      ),
    );
  }

  @override
  void backToTabs({int tab = 0}) {
    _content.currentState?.popUntil((route) => route.isFirst);
    this.tab.value = tab;
  }

  /// Back to the tabs from the side bar. A form with unsaved changes and a
  /// booking in progress ask first, with the same words as leaving them by
  /// Back; a confirmed booking has nothing left to lose.
  Future<bool> _closeInnerScreens() async {
    final navigator = _content.currentState;
    if (navigator == null || !navigator.canPop()) return true;
    if (!_routes.done) {
      if (_routes.top?.popDisposition == RoutePopDisposition.doNotPop &&
          !await confirmDiscardChanges(context)) {
        return false;
      }
      if (!mounted) return false;
      if (bookingOpen.value &&
          !await confirmAction(
            context,
            title: 'Sair do agendamento?',
            message: 'As escolhas deste agendamento serão descartadas.',
            confirmLabel: 'Sair',
            cancelLabel: 'Continuar agendando',
          )) {
        return false;
      }
    }
    if (!mounted) return false;
    navigator.popUntil((route) => route.isFirst);
    return true;
  }

  void _routesChanged() {
    if (!mounted) return;
    final open = _routes.booking && !_routes.done;
    if (open == bookingOpen.value) return;
    // Routes can change while a frame is being built; the side bar listens.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _routesChanged());
      return;
    }
    bookingOpen.value = open;
  }

  /// The content navigator takes the keyboard focus when it is created, so
  /// the first Tab would skip the side bar. On wide windows the focus goes
  /// back to the page, and the first Tab follows the reading order: side bar,
  /// then content. Nothing shows, as nothing is focused yet. The phone keeps
  /// its order.
  void _focusFromStart() {
    if (!mounted || appWindowClassOf(context) != AppWindowClass.expanded) {
      return;
    }
    final node = _content.currentState?.focusNode;
    if (node != null && node.hasPrimaryFocus) node.unfocus();
  }

  /// Built once: a new [Navigator] widget would make every open route build
  /// its page again, and route builders that create a booking draft would
  /// hand the open screens a new, empty one. The screens rebuild by their own
  /// dependencies (AppScope, MediaQuery) instead.
  late final Widget _contentArea = FocusTraversalGroup(
    child: NavigatorPopHandler<Object?>(
      onPopWithResult: (_) => _content.currentState?.maybePop(),
      child: Navigator(
        key: _content,
        observers: [_routes],
        onGenerateInitialRoutes: (_, _) {
          _routes.clear();
          return [
            // The tabs do not take the keyboard focus when the app opens:
            // the first Tab follows the reading order and starts at the
            // side bar. Screens opened later still take it, as before.
            MaterialPageRoute<void>(
              requestFocus: false,
              builder: (_) => const _TabsPage(),
            ),
          ];
        },
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    if (controller.tutor == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (_) => false,
          );
        }
      });
      return const SizedBox.shrink();
    }
    // An account without phone, as one created by Google, completes it once
    // before anything else; a petshop's link then only links.
    if (controller.integrated && controller.accountContactMissing) {
      return const AccountContactScreen();
    }
    if (controller.integrated && controller.companyId == null) {
      return const CompanyAccessScreen();
    }
    final wide = appWindowClassOf(context) == AppWindowClass.expanded;
    if (!_contentShown) {
      _contentShown = true;
      // After the first frame and the focus requests of that frame.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => scheduleMicrotask(_focusFromStart),
      );
    }
    // The same tree on both widths (keyed children), so the navigator and
    // its screens survive a window that crosses the breakpoint.
    return TutorShellScope(
      shell: this,
      child: Material(
        color: AppColors.canvas,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (wide)
              TutorSideBar(key: const ValueKey('tutor.side'), shell: this),
            Expanded(key: const ValueKey('tutor.content'), child: _contentArea),
          ],
        ),
      ),
    );
  }
}

/// Routes of the content navigator, to know what leaving would close.
class _RouteTracker extends NavigatorObserver {
  _RouteTracker(this._changed);
  final VoidCallback _changed;
  final _stack = <Route<dynamic>>[];

  Route<dynamic>? get top => _stack.lastOrNull;
  bool get booking => _stack.any((r) => r.settings.name == bookingRoute.name);
  bool get done => _stack.any((r) => r.settings.name == bookingDoneRoute.name);

  void clear() => _stack.clear();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.add(route);
    _changed();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
    _changed();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
    _changed();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final at = oldRoute == null ? -1 : _stack.indexOf(oldRoute);
    if (newRoute != null && at >= 0) {
      _stack[at] = newRoute;
    } else if (newRoute != null) {
      _stack.add(newRoute);
    } else if (at >= 0) {
      _stack.removeAt(at);
    }
    _changed();
  }
}

/// First route of the content navigator: the four tabs, with the bottom bar
/// on narrow windows and the Atualizar button on wide ones.
class _TabsPage extends StatelessWidget {
  const _TabsPage();

  @override
  Widget build(BuildContext context) {
    final shell = TutorShellScope.maybeOf(context)!;
    return ValueListenableBuilder<int>(
      valueListenable: shell.tab,
      builder: (context, index, _) => _tabs(context, shell, index),
    );
  }

  Widget _tabs(BuildContext context, TutorShell shell, int index) {
    final controller = AppScope.of(context);
    final wide = appWindowClassOf(context) == AppWindowClass.expanded;
    final pages = [
      HomeScreen(onBook: shell.openBooking, onSelectTab: shell.selectTab),
      BookingLandingScreen(onStart: shell.openBooking),
      const PetsScreen(),
      // On wide windows the company is in the side bar.
      ProfileScreen(
        companyActions: controller.integrated && !wide
            ? _CompanyActions(shell: shell)
            : null,
      ),
    ];
    return Scaffold(
      body: SafeArea(
        child: AppRefreshBody(
          onRefresh: shell.refresh,
          child: Column(
            children: [
              if (controller.offline)
                AppOfflineBanner(
                  message: _offlineMessage(controller.connectionProblem, wide),
                ),
              if (controller.error != null && !controller.offline)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(controller.error!),
                ),
              if (controller.linkNotice != null)
                AppNoticeBanner(
                  background: AppColors.noticeSurface,
                  icon: Icons.info_outline,
                  iconColor: AppColors.warning,
                  title: 'Vínculo encerrado',
                  message: controller.linkNotice!,
                  action: TextButton(
                    onPressed: controller.clearLinkNotice,
                    child: const Text('Fechar'),
                  ),
                ),
              if (controller.pendingInvite != null)
                AppNoticeBanner(
                  background: AppColors.noticeSurface,
                  icon: Icons.add_business_outlined,
                  iconColor: AppColors.primary,
                  title: 'Convite de petshop',
                  message: 'Você abriu um link de convite para outra empresa.',
                  action: TextButton(
                    onPressed: controller.busy
                        ? null
                        : () =>
                              controller.acceptLink(controller.pendingInvite!),
                    child: const Text('Vincular'),
                  ),
                ),
              if (controller.returnRequested)
                AppNoticeBanner(
                  background: AppColors.noticeSurface,
                  icon: Icons.hourglass_top_outlined,
                  iconColor: AppColors.primary,
                  title: 'Pedido enviado',
                  message:
                      'O petshop precisa liberar o seu retorno. Quando ele aprovar, atualize o app: o petshop aparece em Trocar empresa.',
                  action: TextButton(
                    onPressed: controller.clearReturnRequested,
                    child: const Text('Fechar'),
                  ),
                ),
              Expanded(
                key: const ValueKey('tutor.tabs'),
                child: IndexedStack(
                  index: index,
                  children: tipTabs(index, pages),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : AppTourTarget(
              id: TipTargets.nav,
              child: NavigationBar(
                selectedIndex: index,
                onDestinationSelected: shell.selectTab,
                destinations: [
                  for (final (icon, selected, label) in tutorDestinations)
                    NavigationDestination(
                      icon: Icon(icon),
                      selectedIcon: Icon(selected),
                      label: label,
                    ),
                ],
              ),
            ),
    );
  }
}

/// Company of the online Tutor at the top of the Profile, on narrow windows.
class _CompanyActions extends StatelessWidget {
  const _CompanyActions({required this.shell});
  final TutorShell shell;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Empresa'),
          subtitle: Text(
            controller.companies
                    .where((company) => company.id == controller.companyId)
                    .firstOrNull
                    ?.name ??
                'Empresa',
          ),
          trailing: controller.companies.length > 1
              ? Tooltip(
                  message: 'Trocar empresa',
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: () => _chooseCompany(context),
                    icon: const Icon(Icons.swap_horiz_rounded),
                    label: const Text('Trocar'),
                  ),
                )
              : null,
        ),
        OutlinedButton.icon(
          onPressed: controller.busy ? null : shell.linkCompany,
          icon: const Icon(Icons.add_business_outlined),
          label: const Text('Vincular outro petshop'),
        ),
        // Apart from the person, under it.
        const SizedBox(height: 24),
      ],
    );
  }
}

/// The petshops in a sheet from the bottom, with the current one marked and
/// Fechar visible. Choosing one selects it, as the menu did; Fechar chooses
/// nothing.
Future<void> _chooseCompany(BuildContext context) {
  final controller = AppScope.of(context);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Trocar empresa', style: Theme.of(sheet).textTheme.titleLarge),
            const SizedBox(height: 12),
            // Scrolls when the window is short, as a phone lying down.
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final company in controller.companies)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _CompanyOption(
                        name: company.name,
                        current: company.id == controller.companyId,
                        onTap: () {
                          Navigator.pop(sheet);
                          controller.selectCompany(company.id);
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            OutlinedButton(
              onPressed: () => Navigator.pop(sheet),
              child: const Text('Fechar'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CompanyOption extends StatelessWidget {
  const _CompanyOption({
    required this.name,
    required this.current,
    required this.onTap,
  });
  final String name;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: 56,
    shape: RoundedRectangleBorder(
      borderRadius: AppRadii.r16,
      side: BorderSide(color: current ? AppColors.primary : AppColors.line),
    ),
    selected: current,
    selectedTileColor: AppColors.mint,
    leading: Icon(
      current ? Icons.check_circle_rounded : Icons.storefront_outlined,
    ),
    title: Text(name),
    onTap: onTap,
  );
}

class BookingLandingScreen extends StatelessWidget {
  const BookingLandingScreen({super.key, required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => AppScreenTips(
    screen: TipScreens.booking,
    tips: tutorTips(context, TutorTips.booking),
    // On wide windows, the header of the other tabs and the next visits.
    child: appWindowClassOf(context) == AppWindowClass.expanded
        ? BookingLandingWide(onStart: onStart)
        : SafeArea(
          // Scrolls only when the window is short, as a phone lying down; standing
          // up, it fills the page as before.
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 48).clamp(0, double.infinity),
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 30),
                      Text(
                        'Um cuidado novo\ncomeça aqui.',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Escolha os pets, os serviços e o melhor horário. Você revisa tudo antes de confirmar.',
                      ),
                      const Spacer(),
                      // The paw of the brand, drawn, instead of the emoji.
                      Center(
                        child: Container(
                          width: 176,
                          height: 176,
                          decoration: const BoxDecoration(
                            color: AppColors.mint,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const AppPawMark(
                            size: 88,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      AppTourTarget(
                        id: TipTargets.bookingStart,
                        child: FilledButton.icon(
                          onPressed: onStart,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Novo agendamento'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          ),
  );
}

/// Offline banner: the reason, then how to try again on this window size.
String _offlineMessage(NetworkProblem problem, bool wide) =>
    problem == NetworkProblem.noInternet
    ? wide
          ? 'Sem internet. Reconecte-se e clique em Atualizar.'
          : 'Sem internet. Reconecte-se e puxe para baixo para atualizar.'
    : wide
    ? '${problem.title}. Clique em Atualizar para tentar de novo.'
    : '${problem.title}. Puxe para baixo para tentar de novo.';
