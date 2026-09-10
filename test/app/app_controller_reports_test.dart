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
    await c.setReportRange(ReportRange.week, kind: 'all-transactions');
    await c.setReportRange(ReportRange.month, kind: 'returns');
    expect(c.reportRangeFor('all-transactions'), ReportRange.week);
    expect(c.reportRangeFor('returns'), ReportRange.month);
  });

  test('setCustomReportRange snaps to a matching quick range', () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await c.setCustomReportRange(
      DateTimeRange(start: today, end: today),
      kind: 'all-transactions',
    );
    expect(c.reportRangeFor('all-transactions'), ReportRange.today);
  });

  test('reportQueryFor includes type when not "all"', () async {
    await c.setCombinedReportType('penjualan');
    final q = c.reportQueryFor('all-transactions');
    expect(q['type'], 'penjualan');
  });

  test('reportQueryFor omits type when "all"', () async {
    final q = c.reportQueryFor('all-transactions');
    expect(q.containsKey('type'), isFalse);
  });

  test('setCombinedReportType clears customer + supplier filter', () async {
    await c.setReportCustomerFilter(5);
    await c.setCombinedReportType('pembelian');
    expect(c.selectedReportCustomerIdFor('all-transactions'), isNull);
    expect(c.selectedReportSupplierIdFor('all-transactions'), isNull);
  });
}
