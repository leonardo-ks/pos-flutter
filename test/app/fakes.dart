// Characterization-test fakes for AppController (Task 1).
//
// Each fake `implements` the real repository interface from lib/src/**, exposes
// a scripted page list plus call counters, and a `throwNext` flag so later
// refactor tasks can reuse them to pin behavior.
import 'package:pos_flutter/src/auth/models/app_user.dart';
import 'package:pos_flutter/src/auth/repositories/auth_repository.dart';
import 'package:pos_flutter/src/customers/models/customer.dart';
import 'package:pos_flutter/src/customers/repositories/customer_repository.dart';
import 'package:pos_flutter/src/inventory/models/product.dart';
import 'package:pos_flutter/src/inventory/repositories/product_repository.dart';
import 'package:pos_flutter/src/pos/models/cart_line.dart';
import 'package:pos_flutter/src/reports/models/sale_transaction.dart';
import 'package:pos_flutter/src/reports/models/sales_report.dart';
import 'package:pos_flutter/src/reports/repositories/report_repository.dart';
import 'package:pos_flutter/src/reports/repositories/transaction_repository.dart';
import 'package:pos_flutter/src/shared/models/feature_record.dart';
import 'package:pos_flutter/src/shared/repositories/feature_repository.dart';

class FakeProductRepository implements ProductRepository {
  FakeProductRepository({
    List<PagedProducts>? pages,
    List<PagedProducts>? morePages,
  }) : _pages = [...?pages],
       _morePages = [...?morePages];

  final List<PagedProducts> _pages;
  final List<PagedProducts> _morePages;
  Object? throwNext;
  int fetchCount = 0;
  int fetchMoreCount = 0;
  int upsertCount = 0;
  int deleteCount = 0;

  PagedProducts _pop(List<PagedProducts> from) => from.isEmpty
      ? const PagedProducts(rows: [], nextCursor: null)
      : from.removeAt(0);

  void _maybeThrow() {
    final err = throwNext;
    if (err != null) {
      throwNext = null;
      throw err;
    }
  }

  @override
  Future<PagedProducts> fetchProductPage({
    String? query,
    int? categoryId,
    int? locationId,
    String? stockFilter,
    String? cursor,
  }) async {
    _maybeThrow();
    if (cursor != null) {
      fetchMoreCount++;
      return _pop(_morePages);
    }
    fetchCount++;
    return _pop(_pages);
  }

  @override
  Future<List<Product>> fetchProducts({String? query}) async => const [];

  @override
  Future<Product> upsertProduct(Product product) async {
    _maybeThrow();
    upsertCount++;
    return product;
  }

  @override
  Future<void> deleteProduct(int id) async {
    _maybeThrow();
    deleteCount++;
  }
}

class FakeCustomerRepository implements CustomerRepository {
  FakeCustomerRepository({
    List<PagedCustomers>? pages,
    List<PagedCustomers>? morePages,
  }) : _pages = [...?pages],
       _morePages = [...?morePages];

  final List<PagedCustomers> _pages;
  final List<PagedCustomers> _morePages;
  Object? throwNext;
  int fetchCount = 0;
  int fetchMoreCount = 0;

  PagedCustomers _pop(List<PagedCustomers> from) => from.isEmpty
      ? const PagedCustomers(rows: [], nextCursor: null)
      : from.removeAt(0);

  void _maybeThrow() {
    final err = throwNext;
    if (err != null) {
      throwNext = null;
      throw err;
    }
  }

  @override
  Future<PagedCustomers> fetchCustomerPage({
    String? query,
    String? cursor,
  }) async {
    _maybeThrow();
    if (cursor != null) {
      fetchMoreCount++;
      return _pop(_morePages);
    }
    fetchCount++;
    return _pop(_pages);
  }

  @override
  Future<List<Customer>> fetchCustomers({String? query}) async => const [];

  @override
  Future<Customer> upsertCustomer(Customer customer) async => customer;

  @override
  Future<void> deleteCustomer(int id) async {}
}

class FakeFeatureRepository implements FeatureRepository {
  final Map<String, List<PagedFeatureRecords>> pagesByPath = {};
  final Map<String, List<FeatureRecord>> seeded = {};
  List<int> exported = const [1, 2, 3];
  Object? throwNext;
  final List<String> listedPaths = [];

  void _maybeThrow() {
    final err = throwNext;
    if (err != null) {
      throwNext = null;
      throw err;
    }
  }

  @override
  Future<List<FeatureRecord>> list(
    String path, {
    Map<String, String>? query,
  }) async {
    return (await listPage(path, query: query)).rows;
  }

  @override
  Future<PagedFeatureRecords> listPage(
    String path, {
    Map<String, String>? query,
  }) async {
    _maybeThrow();
    listedPaths.add(path);
    final scripted = pagesByPath[path];
    if (scripted != null && scripted.isNotEmpty) return scripted.removeAt(0);
    return PagedFeatureRecords(
      rows: seeded[path] ?? const [],
      nextCursor: null,
    );
  }

  @override
  Future<FeatureRecord> save(
    String path,
    Map<String, Object?> body, {
    int? id,
  }) async => FeatureRecord({'id': id ?? 1, ...body});

  @override
  Future<List<FeatureRecord>> saveBatch(
    String path,
    List<Map<String, Object?>> items, {
    List<int> deleteIds = const [],
  }) async => [for (final item in items) FeatureRecord(item)];

  @override
  Future<void> delete(String path, int id) async {}

  @override
  Future<List<int>> exportReport(String kind, Map<String, String> query) async {
    _maybeThrow();
    return exported;
  }
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository(this.users);
  final List<AppUser> users;
  String? lastUsername;

  @override
  Future<AppUser> login({
    required String username,
    required String password,
  }) async {
    lastUsername = username;
    final hint = switch (username) {
      'admin' => 'administrator',
      'manajer' => 'manajer',
      _ => 'kasir',
    };
    return users.firstWhere(
      (u) => u.name.toLowerCase().contains(hint),
      orElse: () => users.first,
    );
  }
}

class FakeReportRepository implements ReportRepository {
  SalesReport report = SalesReport.empty();
  List<int> exported = const [9, 9];
  int fetchCount = 0;

  @override
  Future<SalesReport> fetchSalesReport(
    ReportRange range, {
    DateTime? from,
    DateTime? to,
    int? productId,
    int? categoryId,
    int? customerId,
  }) async {
    fetchCount++;
    return report;
  }

  @override
  Future<List<int>> exportSalesReport({
    required ReportRange range,
    DateTime? from,
    DateTime? to,
    int? productId,
    int? categoryId,
    int? customerId,
  }) async => exported;

  @override
  Map<String, String> rangeQuery(
    ReportRange range, {
    DateTime? from,
    DateTime? to,
    int? productId,
    int? categoryId,
    int? customerId,
  }) {
    final q = <String, String>{'range': range.name};
    if (productId != null) q['product_id'] = '$productId';
    if (categoryId != null) q['category_id'] = '$categoryId';
    if (customerId != null) q['customer_id'] = '$customerId';
    return q;
  }
}

class FakeTransactionRepository implements TransactionRepository {
  final List<SaleTransaction> history = [];
  int createCount = 0;

  @override
  Future<SaleTransaction> createTransaction({
    required AppUser user,
    required Customer? customer,
    required List<CartLine> lines,
    String paymentMethod = 'cash',
    double? cashReceived,
    double? discountAmount,
  }) async {
    createCount++;
    final tx = SaleTransaction(
      id: 1000 + createCount,
      time: DateTime.fromMillisecondsSinceEpoch(0),
      customer: customer,
      user: user,
      items: const [],
      totalBeforeDiscount: 0,
      discount: discountAmount ?? 0,
      totalFinal: 0,
      paymentMethod: paymentMethod,
      cashReceived: cashReceived,
    );
    history.add(tx);
    return tx;
  }

  @override
  Future<List<SaleTransaction>> fetchTransactions({
    required AppUser user,
    required List<Customer> customers,
  }) async => List.of(history);
}
