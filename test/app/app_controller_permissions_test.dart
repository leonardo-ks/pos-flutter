import 'package:flutter_test/flutter_test.dart';
import 'package:pos_flutter/src/app/app_controller.dart';
import 'package:pos_flutter/src/auth/models/app_user.dart';

void main() {
  Future<AppController> loggedInAs(UserRole role) async {
    final c = AppController();
    await c.loginAsRoleForTest(role);
    return c;
  }

  group('canViewSection', () {
    test('cashier sees pos + master only', () async {
      final c = await loggedInAs(UserRole.cashier);
      expect(c.canViewSection(AppSection.pos), isTrue);
      expect(c.canViewSection(AppSection.master), isTrue);
      expect(c.canViewSection(AppSection.reports), isFalse);
      expect(c.canViewSection(AppSection.users), isFalse);
      expect(c.canViewSection(AppSection.purchases), isFalse);
    });

    test('manager sees everything except users', () async {
      final c = await loggedInAs(UserRole.manager);
      expect(c.canViewSection(AppSection.reports), isTrue);
      expect(c.canViewSection(AppSection.purchases), isTrue);
      expect(c.canViewSection(AppSection.returns), isTrue);
      expect(c.canViewSection(AppSection.users), isFalse);
    });

    test('administrator sees every section', () async {
      final c = await loggedInAs(UserRole.administrator);
      for (final s in AppSection.values) {
        expect(c.canViewSection(s), isTrue, reason: '$s');
      }
    });
  });

  group('CRUD verbs by role', () {
    for (final (role, section, canCreate) in const [
      (UserRole.cashier, 'pos', false),
      (UserRole.cashier, 'inventory', false),
      (UserRole.manager, 'inventory', true),
      (UserRole.manager, 'users', false),
      (UserRole.administrator, 'users', true),
    ]) {
      test('$role can_create $section == $canCreate', () async {
        final c = await loggedInAs(role);
        expect(c.canCreateMenu(section), canCreate);
      });
    }
  });

  test('administrator with empty role-permissions cache is allowed everything',
      () async {
    final c = await loggedInAs(UserRole.administrator);
    expect(c.canViewMenu('anything-at-all'), isTrue);
    expect(c.canCreateMenu('anything-at-all'), isTrue);
  });

  test('availableSections is canViewSection filtered, order preserved', () async {
    final c = await loggedInAs(UserRole.manager);
    expect(c.availableSections, AppSection.values.where(c.canViewSection).toList());
  });
}
