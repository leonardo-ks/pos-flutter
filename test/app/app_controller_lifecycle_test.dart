import 'package:flutter_test/flutter_test.dart';
import 'package:pos_flutter/src/app/app_controller.dart';
import 'package:pos_flutter/src/auth/models/app_user.dart';
import 'package:pos_flutter/src/reports/repositories/report_repository.dart';

void main() {
  test('login populates user and loads master-data feature records', () async {
    final c = AppController();
    await c.login(username: 'manajer', password: 'password1234');
    expect(c.isLoggedIn, isTrue);
    expect(c.featureRecords('/api/product-categories'), isNotNull);
    expect(c.customerGroupDiscounts, isNotNull);
  });

  test('logout returns observable state to initial values', () async {
    final c = AppController();
    await c.loginAsRoleForTest(UserRole.manager);
    c.addToCart(c.products.items.first);
    await c.setReportRange(ReportRange.week, kind: 'all-transactions');
    c.logout();

    expect(c.isLoggedIn, isFalse);
    expect(c.selectedSection, AppSection.pos);
    expect(c.cartLines, isEmpty);
    expect(c.customers.selected, isNull);
    expect(c.products.search, '');
    expect(c.selectedReportRange, ReportRange.today);
    expect(c.selectedGenericReport, 'purchases');
    expect(c.errorMessage, isNull);
  });

  test('checkout empties cart, clears customer, returns a transaction', () async {
    final c = AppController();
    await c.loginAsRoleForTest(UserRole.cashier);
    c.customers.select(c.customers.items.first);
    c.addToCart(c.products.items.first);
    final tx = await c.checkout();
    expect(tx, isNotNull);
    expect(c.cartLines, isEmpty);
    expect(c.customers.selected, isNull);
  });

  test('checkout returns null with empty cart', () async {
    final c = AppController();
    await c.loginAsRoleForTest(UserRole.cashier);
    expect(await c.checkout(), isNull);
  });
}
