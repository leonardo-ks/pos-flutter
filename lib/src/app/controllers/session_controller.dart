import 'package:flutter/foundation.dart';

import '../../auth/models/app_user.dart';
import '../../auth/repositories/auth_repository.dart';
import '../../shared/models/feature_record.dart';
import '../app_controller.dart' show AppSection;

class SessionController extends ChangeNotifier {
  SessionController({
    required List<FeatureRecord>? Function() rolePermissionRecords,
  })
    // ignore: prefer_initializing_formals
    : _rolePermissionRecords = rolePermissionRecords;

  final List<FeatureRecord>? Function() _rolePermissionRecords;

  final List<AppUser> demoUsers = const [
    AppUser(id: 1, name: 'Dewi Kasir', role: UserRole.cashier),
    AppUser(id: 2, name: 'Bima Manajer', role: UserRole.manager),
    AppUser(id: 3, name: 'Ari Administrator', role: UserRole.administrator),
  ];

  AppUser? currentUser;

  bool get isLoggedIn => currentUser != null;
  bool get isManager => currentUser?.role == UserRole.manager;
  bool get isAdministrator => currentUser?.role == UserRole.administrator;
  bool get canManage => isManager || isAdministrator;

  List<AppSection> get availableSections {
    const sections = [
      AppSection.pos,
      AppSection.purchases,
      AppSection.returns,
      AppSection.reports,
      AppSection.master,
      AppSection.users,
    ];
    return sections.where(canViewSection).toList(growable: false);
  }

  bool canViewSection(AppSection section) {
    return switch (section) {
      AppSection.pos => canViewMenu('pos'),
      AppSection.purchases => canViewMenu('purchases'),
      AppSection.returns =>
        canViewMenu('purchase-returns') || canViewMenu('sales-returns'),
      AppSection.reports => canViewMenu('reports'),
      AppSection.master =>
        canViewMenu('inventory') ||
            canViewMenu('customers') ||
            canViewMenu('suppliers'),
      AppSection.users =>
        canViewMenu('users') ||
            canViewMenu('roles') ||
            canViewMenu('authorization') ||
            isAdministrator,
    };
  }

  bool canViewMenu(String section) {
    if (isAdministrator && _rolePermissionRecords() == null) return true;
    final permission = _rolePermission(section);
    if (permission != null) return permission.values['can_view'] == true;
    return switch (currentUser?.role) {
      UserRole.administrator => true,
      UserRole.manager => !{
        'users',
        'roles',
        'authorization',
      }.contains(section),
      UserRole.cashier => {'pos', 'inventory', 'customers'}.contains(section),
      null => false,
    };
  }

  bool canCreateMenu(String section) => _canCrud(section, 'can_create');
  bool canUpdateMenu(String section) => _canCrud(section, 'can_update');
  bool canDeleteMenu(String section) => _canCrud(section, 'can_delete');

  bool _canCrud(String section, String key) {
    if (isAdministrator && _rolePermissionRecords() == null) return true;
    final permission = _rolePermission(section);
    if (permission != null) return permission.values[key] == true;
    if (currentUser?.role == UserRole.administrator) return true;
    if (currentUser?.role == UserRole.manager) {
      return !{'users', 'roles', 'authorization'}.contains(section);
    }
    return false;
  }

  FeatureRecord? _rolePermission(String section) {
    final role = currentUser?.permissionRole;
    if (role == null) return null;
    final records = _rolePermissionRecords();
    if (records == null) return null;
    return records
        .where(
          (record) =>
              record.values['role'] == role &&
              record.values['section'] == section,
        )
        .firstOrNull;
  }

  Future<void> authenticate(
    AuthRepository repo, {
    required String username,
    required String password,
  }) async {
    currentUser = await repo.login(username: username, password: password);
    notifyListeners();
  }

  void reset() {
    currentUser = null;
    notifyListeners();
  }
}
