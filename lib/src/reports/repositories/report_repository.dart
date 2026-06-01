import '../../shared/api/api_client.dart';
import '../../shared/data/mock_data_store.dart';
import '../models/sales_report.dart';

enum ReportRange { today, week, month, custom, all }

abstract class ReportRepository {
  Map<String, String> rangeQuery(
    ReportRange range, {
    DateTime? from,
    DateTime? to,
    int? productId,
    int? categoryId,
    int? customerId,
  });

  Future<SalesReport> fetchSalesReport(
    ReportRange range, {
    DateTime? from,
    DateTime? to,
    int? productId,
    int? categoryId,
    int? customerId,
  });

  Future<List<int>> exportSalesReport({
    required ReportRange range,
    DateTime? from,
    DateTime? to,
    int? productId,
    int? categoryId,
    int? customerId,
  });
}

class MockReportRepository implements ReportRepository {
  MockReportRepository(this._store);

  final MockDataStore _store;

  @override
  Map<String, String> rangeQuery(
    ReportRange range, {
    DateTime? from,
    DateTime? to,
    int? productId,
    int? categoryId,
    int? customerId,
  }) {
    final query = <String, String>{};
    if (productId != null) query['product_id'] = productId.toString();
    if (categoryId != null) query['category_id'] = categoryId.toString();
    if (customerId != null) query['customer_id'] = customerId.toString();
    return query;
  }

  @override
  Future<SalesReport> fetchSalesReport(
    ReportRange range, {
    DateTime? from,
    DateTime? to,
    int? productId,
    int? categoryId,
    int? customerId,
  }) async {
    final transactions = _store.transactions
        .where((transaction) {
          final now = DateTime.now();
          return switch (range) {
            ReportRange.today =>
              transaction.time.year == now.year &&
                  transaction.time.month == now.month &&
                  transaction.time.day == now.day,
            ReportRange.week =>
              !transaction.time.isBefore(
                    DateTime(
                      now.year,
                      now.month,
                      now.day,
                    ).subtract(Duration(days: now.weekday - 1)),
                  ) &&
                  transaction.time.isBefore(
                    DateTime(now.year, now.month, now.day + 1),
                  ),
            ReportRange.month =>
              transaction.time.year == now.year &&
                  transaction.time.month == now.month,
            ReportRange.custom =>
              (from == null || !transaction.time.isBefore(from)) &&
                  (to == null || transaction.time.isBefore(to)),
            ReportRange.all => true,
          };
        })
        .toList(growable: false);

    final totals = <String, ({int productId, int quantity, double revenue})>{};
    for (final transaction in transactions) {
      for (final item in transaction.items) {
        final current = totals[item.productName];
        totals[item.productName] = (
          productId: item.productId,
          quantity: (current?.quantity ?? 0) + item.quantity,
          revenue: (current?.revenue ?? 0) + item.subtotal,
        );
      }
    }

    final topProducts =
        totals.entries
            .map(
              (entry) => TopProduct(
                productId: entry.value.productId,
                name: entry.key,
                quantitySold: entry.value.quantity,
                revenue: entry.value.revenue,
              ),
            )
            .toList()
          ..sort((a, b) => b.quantitySold.compareTo(a.quantitySold));

    return SalesReport(
      revenue: transactions.fold(0, (total, item) => total + item.totalFinal),
      transactionCount: transactions.length,
      itemCount: transactions.fold(0, (total, item) => total + item.itemCount),
      topProducts: topProducts.take(5).toList(growable: false),
      recentTransactions: transactions
          .map(
            (transaction) => RecentSale(
              id: transaction.id,
              time: transaction.time,
              customerName: transaction.customer?.name,
              cashierName: transaction.user.name,
              totalFinal: transaction.totalFinal,
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<List<int>> exportSalesReport({
    required ReportRange range,
    DateTime? from,
    DateTime? to,
    int? productId,
    int? categoryId,
    int? customerId,
  }) async {
    return const [];
  }
}

class ApiReportRepository implements ReportRepository {
  ApiReportRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<SalesReport> fetchSalesReport(
    ReportRange range, {
    DateTime? from,
    DateTime? to,
    int? productId,
    int? categoryId,
    int? customerId,
  }) {
    return _apiClient.get<SalesReport>(
      '/api/reports/sales',
      (data) => SalesReport.fromJson((data as Map).cast<String, Object?>()),
      query: rangeQuery(
        range,
        from: from,
        to: to,
        productId: productId,
        categoryId: categoryId,
        customerId: customerId,
      ),
    );
  }

  @override
  Future<List<int>> exportSalesReport({
    required ReportRange range,
    DateTime? from,
    DateTime? to,
    int? productId,
    int? categoryId,
    int? customerId,
  }) {
    return _apiClient.download(
      '/api/reports/sales/export',
      query: rangeQuery(
        range,
        from: from,
        to: to,
        productId: productId,
        categoryId: categoryId,
        customerId: customerId,
      ),
    );
  }

  @override
  Map<String, String> rangeQuery(
    ReportRange range, {
    DateTime? from,
    DateTime? to,
    int? productId,
    int? categoryId,
    int? customerId,
  }) {
    final now = DateTime.now();
    final Map<String, String> query = switch (range) {
      ReportRange.today => {
        'from': DateTime(now.year, now.month, now.day).toIso8601String(),
        'to': DateTime(now.year, now.month, now.day + 1).toIso8601String(),
      },
      ReportRange.week => {
        'from': DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: now.weekday - 1)).toIso8601String(),
        'to': DateTime(now.year, now.month, now.day + 1).toIso8601String(),
      },
      ReportRange.month => {
        'from': DateTime(now.year, now.month).toIso8601String(),
        'to': DateTime(now.year, now.month + 1).toIso8601String(),
      },
      ReportRange.all => {},
      ReportRange.custom => {
        if (from != null) 'from': from.toIso8601String(),
        if (to != null) 'to': to.toIso8601String(),
      },
    };
    if (productId != null) query['product_id'] = productId.toString();
    if (categoryId != null) query['category_id'] = categoryId.toString();
    if (customerId != null) query['customer_id'] = customerId.toString();
    return query;
  }
}
