import 'package:flutter/material.dart';

import '../../auth/models/app_user.dart';
import '../../customers/models/customer.dart';
import '../../reports/models/sale_transaction.dart';
import '../../reports/models/sales_report.dart';
import '../../reports/repositories/report_repository.dart';
import '../../reports/repositories/transaction_repository.dart';
import '../async_guard.dart';
import 'report_filter_state.dart';

class ReportController extends ChangeNotifier {
  ReportController(
    this._guard,
    this._reportRepo,
    this._txRepo, {
    required bool Function() canManage,
    required List<Customer> Function() customers,
    required Future<void> Function(String kind, {String? search}) loadGenericReport,
    required Future<void> Function(String kind, {String? search}) loadMoreGenericReport,
  })  :
        // ignore: prefer_initializing_formals
        _canManage = canManage,
        // ignore: prefer_initializing_formals
        _customers = customers,
        // ignore: prefer_initializing_formals
        _loadGenericReport = loadGenericReport,
        // ignore: prefer_initializing_formals
        _loadMoreGenericReport = loadMoreGenericReport;

  final AsyncGuard _guard;
  final ReportRepository _reportRepo;
  final TransactionRepository _txRepo;
  final bool Function() _canManage;
  final List<Customer> Function() _customers;
  final Future<void> Function(String kind, {String? search}) _loadGenericReport;
  // ignore: unused_field  (kept for symmetry; wire a caller if a "load more" report control needs it)
  final Future<void> Function(String kind, {String? search}) _loadMoreGenericReport;

  final ReportFilterState report = ReportFilterState();
  final ReportFilterState returnReport = ReportFilterState();

  SalesReport _salesReport = SalesReport.empty();
  List<SaleTransaction> _transactions = const [];

  SalesReport get salesReport => _salesReport;
  List<SaleTransaction> get transactions => List.unmodifiable(_transactions);

  ReportFilterState filterFor(String kind) =>
      kind == 'returns' ? returnReport : report;

  ReportRange reportRangeFor(String kind) => filterFor(kind).range;

  DateTimeRange? customReportRangeFor(String kind) {
    final f = filterFor(kind);
    if (f.range == ReportRange.custom) return f.customRange;
    return _quickDateRange(f.range);
  }

  Future<void> loadSalesReport(ReportRange range) async {
    if (!_canManage()) return;
    report.range = range;
    await _guard.run(() async {
      _salesReport = await _reportRepo.fetchSalesReport(
        range,
        from: report.customRange?.start,
        to: _exclusiveEnd(report.customRange?.end),
        productId: report.productId,
        categoryId: report.categoryId,
        customerId: report.customerId,
      );
    });
  }

  Future<void> setRange(ReportRange range, {required String kind}) async {
    final f = filterFor(kind);
    f.range = range;
    if (range != ReportRange.custom) f.customRange = null;
    if (kind == 'returns') {
      await _loadGenericReport('returns');
      return;
    }
    await loadSalesReport(range);
    await _loadGenericReport('all-transactions');
  }

  Future<void> setCustomRange(DateTimeRange range,
      {String kind = 'all-transactions'}) async {
    final matched = _matchingQuickRange(range);
    final f = filterFor(kind);
    f.range = matched ?? ReportRange.custom;
    f.customRange = matched == null ? range : null;
    if (kind == 'returns') {
      await _loadGenericReport('returns');
      return;
    }
    await loadSalesReport(f.range);
    await _loadGenericReport('all-transactions');
  }

  Future<void> setProductFilter(int? id, {String kind = 'all-transactions'}) async {
    filterFor(kind).productId = id;
    notifyListeners();
    if (kind == 'returns') {
      await _loadGenericReport('returns');
      return;
    }
    await loadSalesReport(report.range);
    await _loadGenericReport('all-transactions');
  }

  Future<void> setCategoryFilter(int? id, {String kind = 'all-transactions'}) async {
    filterFor(kind).categoryId = id;
    notifyListeners();
    if (kind == 'returns') {
      await _loadGenericReport('returns');
      return;
    }
    await loadSalesReport(report.range);
    await _loadGenericReport('all-transactions');
  }

  Future<void> setCustomerFilter(int? id, {String kind = 'all-transactions'}) async {
    filterFor(kind).customerId = id;
    notifyListeners();
    if (kind == 'returns') {
      await _loadGenericReport('returns');
      return;
    }
    await loadSalesReport(report.range);
    await _loadGenericReport('all-transactions');
  }

  Future<void> setSupplierFilter(int? id, {String kind = 'all-transactions'}) async {
    filterFor(kind).supplierId = id;
    notifyListeners();
    if (kind == 'returns') {
      await _loadGenericReport('returns');
      return;
    }
    await _loadGenericReport('all-transactions');
  }

  Future<void> setCombinedType(String type) async {
    report.type = type;
    report.customerId = null;
    report.supplierId = null;
    notifyListeners();
    await _loadGenericReport('all-transactions');
  }

  Future<void> setReturnType(String type) async {
    returnReport.type = type;
    returnReport.customerId = null;
    returnReport.supplierId = null;
    notifyListeners();
    await _loadGenericReport('returns');
  }

  Future<List<int>?> exportSalesReport() async {
    List<int>? bytes;
    await _guard.run(() async {
      bytes = await _reportRepo.exportSalesReport(
        range: report.range,
        from: report.customRange?.start,
        to: _exclusiveEnd(report.customRange?.end),
        productId: report.productId,
        categoryId: report.categoryId,
        customerId: report.customerId,
      );
    });
    return bytes;
  }

  Map<String, String> reportQuery({String? kind, String? search}) {
    final reportKind = kind ?? 'all-transactions';
    final f = filterFor(reportKind);
    final range = f.range;
    final customRange = customReportRangeFor(reportKind);
    final type = f.type;
    final categoryId = f.categoryId;
    final productId = categoryId == null ? null : f.productId;
    final isSalesType = type == 'penjualan' || type == 'retur penjualan';
    final isPurchaseType = type == 'pembelian' || type == 'retur pembelian';
    final rangeQuery = _reportRepo.rangeQuery(
      range,
      from: customRange?.start,
      to: _exclusiveEnd(customRange?.end),
      productId: productId,
      categoryId: categoryId,
      customerId: isSalesType ? f.customerId : null,
    );
    if (type != 'all') rangeQuery['type'] = type;
    final supplierId = isPurchaseType ? f.supplierId : null;
    if (supplierId != null) rangeQuery['supplier_id'] = supplierId.toString();
    final searchText = search?.trim();
    if (searchText != null && searchText.isNotEmpty) {
      rangeQuery['search'] = searchText;
    }
    return rangeQuery;
  }

  Future<void> refetchTransactions(AppUser user) async {
    _transactions =
        await _txRepo.fetchTransactions(user: user, customers: _customers());
  }

  Future<void> refetchSalesReportIfManager() async {
    if (!_canManage()) return;
    _salesReport = await _reportRepo.fetchSalesReport(
      report.range,
      from: report.customRange?.start,
      to: _exclusiveEnd(report.customRange?.end),
      productId: report.productId,
      categoryId: report.categoryId,
      customerId: report.customerId,
    );
  }

  DateTime? _exclusiveEnd(DateTime? date) =>
      date == null ? null : DateTime(date.year, date.month, date.day + 1);

  DateTimeRange? _quickDateRange(ReportRange range) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (range) {
      ReportRange.today => DateTimeRange(start: today, end: today),
      ReportRange.week => DateTimeRange(
          start: today.subtract(Duration(days: today.weekday - 1)),
          end: today,
        ),
      ReportRange.month => DateTimeRange(
          start: DateTime(today.year, today.month),
          end: DateTime(today.year, today.month + 1, 0),
        ),
      ReportRange.custom || ReportRange.all => null,
    };
  }

  ReportRange? _matchingQuickRange(DateTimeRange range) {
    final start = DateTime(range.start.year, range.start.month, range.start.day);
    final end = DateTime(range.end.year, range.end.month, range.end.day);
    for (final candidate in [
      ReportRange.today,
      ReportRange.week,
      ReportRange.month,
    ]) {
      final quick = _quickDateRange(candidate);
      if (quick == null) continue;
      if (quick.start == start && quick.end == end) return candidate;
    }
    return null;
  }

  void reset() {
    report.reset();
    returnReport.reset();
    _salesReport = SalesReport.empty();
    _transactions = const [];
    notifyListeners();
  }
}
