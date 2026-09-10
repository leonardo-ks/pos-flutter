import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_flutter/src/app/app_controller.dart';
import 'package:pos_flutter/src/auth/models/app_user.dart';
import 'package:pos_flutter/src/reports/repositories/report_repository.dart';

void main() {
  late AppController c;

  setUp(() async {
    c = AppController();
    await c.loginAsRoleForTest(UserRole.manager);
  });

  test('reportRangeFor dispatches on kind', () async {
    await c.reports.setRange(ReportRange.week, kind: 'all-transactions');
    await c.reports.setRange(ReportRange.month, kind: 'returns');
    expect(c.reports.reportRangeFor('all-transactions'), ReportRange.week);
    expect(c.reports.reportRangeFor('returns'), ReportRange.month);
  });

  test('setCustomReportRange snaps to a matching quick range', () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await c.reports.setCustomRange(
      DateTimeRange(start: today, end: today),
      kind: 'all-transactions',
    );
    expect(c.reports.reportRangeFor('all-transactions'), ReportRange.today);
  });

  test('reportQueryFor includes type when not "all"', () async {
    await c.reports.setCombinedType('penjualan');
    final q = c.reports.reportQuery(kind: 'all-transactions');
    expect(q['type'], 'penjualan');
  });

  test('reportQueryFor omits type when "all"', () async {
    final q = c.reports.reportQuery(kind: 'all-transactions');
    expect(q.containsKey('type'), isFalse);
  });

  test('setCombinedReportType clears customer + supplier filter', () async {
    await c.reports.setCustomerFilter(5);
    await c.reports.setCombinedType('pembelian');
    expect(c.reports.filterFor('all-transactions').customerId, isNull);
    expect(c.reports.filterFor('all-transactions').supplierId, isNull);
  });
}
