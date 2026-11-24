import 'package:flutter/foundation.dart';
import '../domain/models.dart';
import 'app_controller.dart';
import '../modules/professional/state/app_controller.dart' as pro;
import '../modules/driver/state/app_controller.dart' as delivery;

/// Coordinates UI sessions; each business module keeps its own repository,
/// commands, authorization and private cache. No role impersonates another UID.
class WorkforceController extends ChangeNotifier {
  WorkforceController(this.team, this.professional, this.driver) {
    _revision = team.sessionRevision;
    team.addListener(_contextChanged);
  }
  late int _revision;
  void _contextChanged() {
    final changed = _revision != team.sessionRevision;
    _revision = team.sessionRevision;
    if (_closing || _switching) return;
    if (_function != null && (changed || !functions.contains(_function))) {
      resetSelection();
    } else {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    team.removeListener(_contextChanged);
    super.dispose();
  }

  final AppController team;
  final pro.AppController professional;
  final delivery.AppController driver;
  TenantRole? _function;
  TenantRole? get function => _function;
  bool _switching = false, _closing = false;
  bool get busy => _switching || team.busy || professional.busy || driver.busy;
  bool get hasUnconfirmed =>
      team.hasPendingCommands ||
      professional.hasPendingCommands ||
      driver.hasPendingCommands;
  String? _error;
  String? get error => _error;
  int _epoch = 0;
  Future<void> _ending = Future.value();
  Future<void> get closingSession => _ending;
  bool _allCompanies = false;
  bool get allCompanies => _allCompanies && canViewAll;
  bool get canViewAll =>
      team.companies.length > 1 &&
      team.companies.any(
        (company) => company.user.availableRoles.contains(TenantRole.manager),
      );
  int _viewRevision = 0;
  int get viewRevision => _viewRevision;
  int allTabIndex = -1;
  List<TenantRole> get functions => allCompanies
      ? TenantRole.values
            .where(
              (role) => team.companies.any(
                (company) => company.user.availableRoles.contains(role),
              ),
            )
            .toList()
      : team.company?.user.availableRoles ?? [];

  bool selectAllCompanies() {
    if (!canViewAll || busy || hasUnconfirmed) return false;
    _allCompanies = true;
    ++_viewRevision;
    allTabIndex = -1;
    notifyListeners();
    return true;
  }

  /// Preparing an item does not replace the shared filter with its origin.
  Future<bool> openCompany(String id, TenantRole role) async {
    if (!allCompanies || busy || hasUnconfirmed) return false;
    return _selectContext(id, role, requireRole: true);
  }

  Future<bool> selectFunction(TenantRole role) async {
    if (busy || !functions.contains(role)) return false;
    if (hasUnconfirmed) {
      _error =
          'Confirme a operação pendente ou atualize antes de trocar de função.';
      notifyListeners();
      return false;
    }
    var id = team.company?.id;
    if (allCompanies &&
        team.company?.user.availableRoles.contains(role) != true) {
      final eligible = team.companies.where(
        (company) => company.user.availableRoles.contains(role),
      );
      if (eligible.isEmpty) return false;
      id = eligible.first.id;
    }
    if (id == null) return false;
    allTabIndex = -1;
    return _selectContext(id, role, requireRole: true);
  }

  Future<bool> selectCompany(String id) async {
    if (busy) return false;
    if (hasUnconfirmed) {
      _error =
          'Confirme a operação pendente ou atualize antes de trocar de empresa.';
      notifyListeners();
      return false;
    }
    _allCompanies = false;
    return _selectContext(id, _function, requireRole: false);
  }

  Future<bool> _selectContext(
    String id,
    TenantRole? preferred, {
    required bool requireRole,
  }) async {
    final epoch = ++_epoch;
    ++_viewRevision;
    _switching = true;
    _function = null;
    _error = null;
    professional.detachView();
    driver.detachView();
    notifyListeners();
    try {
      final selected = await team.selectCompany(id);
      if (epoch != _epoch) return false;
      if (!selected) {
        throw FormatException(
          team.error ?? 'Não foi possível abrir esta empresa.',
        );
      }
      final available = team.company?.user.availableRoles ?? <TenantRole>[];
      if (available.isEmpty || requireRole && !available.contains(preferred)) {
        throw const FormatException('Função removida neste petshop.');
      }
      final role = available.contains(preferred) ? preferred! : available.first;
      team.setFunction(role);
      final success = switch (role) {
        TenantRole.professional => await professional.enterCompany(id),
        TenantRole.driver => await driver.enterCompany(id),
        _ => true,
      };
      if (epoch != _epoch) return false;
      if (!success) {
        throw FormatException(
          professional.error ??
              driver.error ??
              'Não foi possível abrir esta função.',
        );
      }
      _function = role;
      return true;
    } catch (error) {
      if (epoch == _epoch) {
        _error = error is FormatException
            ? error.message
            : 'Não foi possível abrir esta função.';
      }
      return false;
    } finally {
      if (epoch == _epoch) {
        _switching = false;
        notifyListeners();
      }
    }
  }

  void resetSelection() {
    ++_epoch;
    ++_viewRevision;
    if (team.companies.isEmpty) _allCompanies = false;
    _function = null;
    _error = null;
    _switching = false;
    professional.detachView();
    driver.detachView();
    notifyListeners();
  }

  void signOut() {
    if (_closing) return;
    _closing = true;
    _allCompanies = false;
    allTabIndex = -1;
    ++_viewRevision;
    ++_epoch;
    _function = null;
    _error = null;
    _switching = false;
    team.signOut();
    professional.signOut();
    driver.signOut();
    _ending = Future.wait([
      team.closingSession,
      professional.closingSession,
      driver.closingSession,
    ]);
    _closing = false;
    notifyListeners();
  }
}
