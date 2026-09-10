# AppController Split Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Break the 1068-line `AppController` god object into seven focused, namespaced sub-controllers plus a shared `AsyncGuard`, preserving behavior exactly.

**Architecture:** `AppController` stays the object `AppScope` (an `InheritedNotifier`) holds, but becomes a thin owner: it builds repositories, builds sub-controllers in dependency order, exposes them as `final` fields (`session`, `cart`, `navigation`, `products`, `customers`, `featureRecords`, `reports`), and re-broadcasts every child `notifyListeners()` in one hop. Screens move from `AppScope.of(context).saveProduct(...)` to `AppScope.of(context).products.save(...)`. Four genuinely cross-domain methods (`login`, `logout`, `refreshData`, `checkout`) stay on `AppController` as orchestration methods that hold no state.

**Tech Stack:** Flutter (Dart SDK `^3.12.0`), `ChangeNotifier`/`InheritedNotifier` for state, `flutter_test` only (no mockito — fakes are hand-rolled or reuse the existing `Mock*Repository` classes seeded from `MockDataStore`).

## Global Constraints

- Dart SDK floor: `^3.12.0`. No new dependencies (`pubspec.yaml` `dependencies:` unchanged).
- No repository, API-client, or model changes. Only `lib/src/app/**` and screen call sites move.
- Behavior-preserving: no change to permission results, money math, rebuild timing, or screen behavior.
- `AppScope` stays `InheritedNotifier<AppController>`; `AppScope.of(context)` signature unchanged.
- Every sub-controller is a `ChangeNotifier`. `AppController` subscribes to each child with `addListener(notifyListeners)` in its constructor and removes the listeners + disposes children in `dispose()`.
- No sub-controller holds a reference to `AppController`. Cross-controller needs are constructor-injected (a sibling controller, or a `Type Function()` callback while the sibling does not yet exist).
- After every task: `flutter analyze` reports no issues AND `flutter test` is green (the new `test/app/` suite + the existing `test/widget_test.dart`).
- Commit after every task. Commit message prefix `refactor:` for extraction steps, `test:` for Task 1.
- Existing `test/widget_test.dart` calls several members directly on `AppController` (`discountAmount`, `grandTotal`, `selectSection`, `selectedSection`, `addToCart`, `selectCustomer`, `customers`, `products`, `transactions`, `loginAsRoleForTest`). Each task that moves one of those updates `test/widget_test.dart` in the same commit.

---

## File Structure

**New files:**

| Path | Responsibility |
|---|---|
| `lib/src/app/async_guard.dart` | `AsyncGuard` — busy-depth counter, `isBusy`, `errorMessage`, `run(action)`, `reportError`, `clearError`. The one place `_runBusy` logic lives. |
| `lib/src/app/controllers/navigation_controller.dart` | `NavigationController` — `selectedSection`, `selectSection`. |
| `lib/src/app/controllers/session_controller.dart` | `SessionController` — current user, demo users, `authenticate`, `reset`, all permission logic. |
| `lib/src/app/controllers/product_controller.dart` | `ProductController` — product list, cursor, search + 3 filters, load/loadMore/save/delete, `reset`. |
| `lib/src/app/controllers/customer_controller.dart` | `CustomerController` — customer list, cursor, `selected`, search/loadMore/save/delete, `reset`. |
| `lib/src/app/controllers/feature_record_controller.dart` | `FeatureRecordController` — keyed master-data cache, load/loadMore/save/delete, generic-report loads, exports, `reset`. |
| `lib/src/app/controllers/report_filter_state.dart` | `ReportFilterState` — one report's range + filter fields, `reset`. Plain class, not a notifier. |
| `lib/src/app/controllers/report_controller.dart` | `ReportController` — `salesReport`, `transactions`, generic-report selection, range helpers, two `ReportFilterState` instances, `reset`. |
| `lib/src/app/controllers/cart_controller.dart` | `CartController` — cart map, line math, payment, discount rate. |
| `test/app/fakes.dart` | Hand-rolled fake repositories with controllable pages/errors, shared by the suite. |
| `test/app/app_controller_permissions_test.dart` | Permission matrix characterization tests. |
| `test/app/app_controller_cart_test.dart` | Cart math characterization tests. |
| `test/app/app_controller_reports_test.dart` | Report range + query-map characterization tests. |
| `test/app/app_controller_paging_test.dart` | Paging / cursor characterization tests. |
| `test/app/app_controller_lifecycle_test.dart` | `login` / `logout` / `checkout` characterization tests. |

**Modified files:**

| Path | Change |
|---|---|
| `lib/src/app/app_controller.dart` | Shrinks 1068 → ~130 lines: construction + re-broadcast + 4 orchestration methods + delegating getters. |
| `lib/src/app/app_scope.dart` | Unchanged (listed for orientation only). |
| `lib/src/app/pos_kasir_app.dart` | `_controller.isLoggedIn` → `_controller.session.isLoggedIn` (1 site). |
| `lib/src/app/home_shell.dart` | 3 call sites → namespaced. |
| `lib/src/auth/screens/login_screen.dart` | 1 call site. |
| `lib/src/authorization/screens/authorization_screen.dart` | 3 call sites. |
| `lib/src/customers/screens/customer_screen.dart` | 7 call sites. |
| `lib/src/inventory/screens/inventory_screen.dart` | 8 call sites. |
| `lib/src/pos/screens/pos_screen.dart` | 6 call sites. |
| `lib/src/purchases/screens/purchase_screen.dart` | 6 call sites. |
| `lib/src/reports/screens/reports_screen.dart` | 9 call sites. |
| `lib/src/returns/screens/returns_screen.dart` | 13 call sites. |
| `lib/src/shared/widgets/feature_table_screen.dart` | 7 call sites. |
| `test/widget_test.dart` | Namespaced member access, updated per task as members move. |

---

## Task 1: Characterization test suite

Pins current `AppController` behavior before any refactor. Every later task keeps this suite green.

**Files:**
- Create: `test/app/fakes.dart`
- Create: `test/app/app_controller_permissions_test.dart`
- Create: `test/app/app_controller_cart_test.dart`
- Create: `test/app/app_controller_reports_test.dart`
- Create: `test/app/app_controller_paging_test.dart`
- Create: `test/app/app_controller_lifecycle_test.dart`

**Interfaces:**
- Consumes: current public API of `AppController`, `MockDataStore.seeded()`, `UserRole` from `lib/src/auth/models/app_user.dart`, the repository interfaces in `lib/src/*/repositories/*.dart`.
- Produces: `test/app/fakes.dart` exporting `FakeProductRepository`, `FakeCustomerRepository`, `FakeFeatureRepository`, `FakeAuthRepository`, `FakeReportRepository`, `FakeTransactionRepository` — each with a scripted page list and a `throwNext` flag. Later tasks reuse these.

- [ ] **Step 1: Read the contracts the fakes must satisfy**

Read and copy the exact method signatures into the fakes:
`lib/src/inventory/repositories/product_repository.dart`,
`lib/src/customers/repositories/customer_repository.dart`,
`lib/src/shared/repositories/feature_repository.dart`,
`lib/src/auth/repositories/auth_repository.dart`,
`lib/src/reports/repositories/report_repository.dart`,
`lib/src/reports/repositories/transaction_repository.dart`.
Also read `lib/src/reports/models/sale_transaction.dart` and `lib/src/reports/models/sales_report.dart` for the constructors the fakes build (`SaleTransaction.empty()` / `SalesReport.empty()` names are used below — adjust to the real constructors).

- [ ] **Step 2: Write `test/app/fakes.dart`**

```dart
import 'package:pos_flutter/src/auth/models/app_user.dart';
import 'package:pos_flutter/src/auth/repositories/auth_repository.dart';
import 'package:pos_flutter/src/customers/models/customer.dart';
import 'package:pos_flutter/src/customers/repositories/customer_repository.dart';
import 'package:pos_flutter/src/inventory/models/product.dart';
import 'package:pos_flutter/src/inventory/repositories/product_repository.dart';
import 'package:pos_flutter/src/reports/models/sale_transaction.dart';
import 'package:pos_flutter/src/reports/models/sales_report.dart';
import 'package:pos_flutter/src/reports/repositories/report_repository.dart';
import 'package:pos_flutter/src/reports/repositories/transaction_repository.dart';
import 'package:pos_flutter/src/shared/models/feature_record.dart';
import 'package:pos_flutter/src/shared/repositories/feature_repository.dart';

class FakeProductRepository implements ProductRepository {
  FakeProductRepository({List<PagedProducts>? pages, List<PagedProducts>? morePages})
      : _pages = [...?pages],
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
  FakeCustomerRepository({List<PagedCustomers>? pages, List<PagedCustomers>? morePages})
      : _pages = [...?pages],
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
  Future<PagedCustomers> fetchCustomerPage({String? query, String? cursor}) async {
    _maybeThrow();
    if (cursor != null) {
      fetchMoreCount++;
      return _pop(_morePages);
    }
    fetchCount++;
    return _pop(_pages);
  }

  @override
  Future<Customer> upsertCustomer(Customer customer) async => customer;

  @override
  Future<void> deleteCustomer(int id) async {}
}

class FakeFeatureRepository implements FeatureRepository {
  final Map<String, List<FeatureRecordPage>> pagesByPath = {};
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
  Future<FeatureRecordPage> listPage(String path, {Map<String, String>? query}) async {
    _maybeThrow();
    listedPaths.add(path);
    final scripted = pagesByPath[path];
    if (scripted != null && scripted.isNotEmpty) return scripted.removeAt(0);
    return FeatureRecordPage(rows: seeded[path] ?? const [], nextCursor: null);
  }

  @override
  Future<FeatureRecord> save(String path, Map<String, Object?> body, {int? id}) async =>
      FeatureRecord(id: id ?? 1, label: '', values: body);

  @override
  Future<void> saveBatch(String path, List<Map<String, Object?>> items,
      {List<int> deleteIds = const []}) async {}

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
  Future<AppUser> login({required String username, required String password}) async {
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
  Future<SalesReport> fetchSalesReport(ReportRange range,
      {DateTime? from, DateTime? to, int? productId, int? categoryId, int? customerId}) async {
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
  }) async =>
      exported;

  @override
  Map<String, String> rangeQuery(ReportRange range,
      {DateTime? from, DateTime? to, int? productId, int? categoryId, int? customerId}) {
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
    Customer? customer,
    required List<dynamic> lines,
    required String paymentMethod,
    required double cashReceived,
    required double discountAmount,
  }) async {
    createCount++;
    final tx = SaleTransaction.empty();
    history.add(tx);
    return tx;
  }

  @override
  Future<List<SaleTransaction>> fetchTransactions({
    required AppUser user,
    required List<Customer> customers,
  }) async =>
      List.of(history);
}
```

> If any signature above does not match the real interface from Step 1, change the fake to match — it must `implements` the real interface and compile. Fix constructor names (`PagedProducts`, `PagedCustomers`, `FeatureRecordPage`, `SaleTransaction.empty`, `SalesReport.empty`, `FeatureRecord`) to the actual ones.

- [ ] **Step 3: Confirm the fakes compile**

Run: `flutter analyze test/app/fakes.dart`
Expected: `No issues found!` (fix mismatches until clean).

- [ ] **Step 4: Write `test/app/app_controller_permissions_test.dart`**

```dart
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

  test('administrator with empty role-permissions cache is allowed everything', () async {
    final c = await loggedInAs(UserRole.administrator);
    expect(c.canViewMenu('anything-at-all'), isTrue);
    expect(c.canCreateMenu('anything-at-all'), isTrue);
  });

  test('availableSections is canViewSection filtered, order preserved', () async {
    final c = await loggedInAs(UserRole.manager);
    expect(c.availableSections, AppSection.values.where(c.canViewSection).toList());
  });
}
```

- [ ] **Step 5: Write `test/app/app_controller_cart_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_flutter/src/app/app_controller.dart';
import 'package:pos_flutter/src/auth/models/app_user.dart';

void main() {
  late AppController c;

  setUp(() async {
    c = AppController();
    await c.loginAsRoleForTest(UserRole.cashier);
  });

  test('addToCart respects stock cap', () {
    final p = c.products.first;
    for (var i = 0; i < p.stock + 5; i++) {
      c.addToCart(p);
    }
    final line = c.cartLines.firstWhere((l) => l.product.id == p.id);
    expect(line.quantity, p.stock);
  });

  test('decrementCart removes the line at quantity 1', () {
    final p = c.products.first;
    c.addToCart(p);
    c.decrementCart(p);
    expect(c.cartLines.where((l) => l.product.id == p.id), isEmpty);
  });

  test('setCartQuantity clamps into 1..stock', () {
    final p = c.products.first;
    c.setCartQuantity(p, '99999');
    expect(c.cartLines.first.quantity, p.stock);
    c.setCartQuantity(p, '0');
    expect(c.cartLines, isEmpty);
  });

  test('VIP discount math matches widget_test expectation', () {
    c.selectCustomer(c.customers.first);
    c.addToCart(c.products.first);
    expect(c.discountAmount, 1800);
    expect(c.grandTotal, 16200);
  });

  test('cashChange only applies for cash payment', () {
    c.addToCart(c.products.first);
    c.setCashReceived('20000');
    expect(c.cashChange, 20000 - c.grandTotal);
    c.selectPaymentMethod('transfer');
    expect(c.cashChange, 0);
  });

  test('canCheckout gates', () {
    expect(c.canCheckout, isFalse);
    c.addToCart(c.products.first);
    c.setCashReceived('1');
    expect(c.canCheckout, isFalse);
    c.setCashReceived('999999');
    expect(c.canCheckout, isTrue);
    c.selectPaymentMethod('transfer');
    expect(c.canCheckout, isTrue);
  });
}
```

- [ ] **Step 6: Write `test/app/app_controller_reports_test.dart`**

```dart
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
```

- [ ] **Step 7: Write `test/app/app_controller_paging_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_flutter/src/app/app_controller.dart';
import 'package:pos_flutter/src/auth/models/app_user.dart';
import 'package:pos_flutter/src/customers/repositories/customer_repository.dart';
import 'package:pos_flutter/src/inventory/models/product.dart';
import 'package:pos_flutter/src/inventory/repositories/product_repository.dart';
import 'fakes.dart';

void main() {
  test('loadMoreProducts appends and advances the cursor, then stops', () async {
    // Fill Product(...) required fields from lib/src/inventory/models/product.dart.
    final p1 = Product(id: 1 /* , ...required */);
    final p2 = Product(id: 2 /* , ...required */);
    final products = FakeProductRepository(
      pages: [PagedProducts(rows: [p1], nextCursor: 'c1')],
      morePages: [PagedProducts(rows: [p2], nextCursor: null)],
    );
    final c = AppController(productRepository: products);
    await c.loginAsRoleForTest(UserRole.manager); // refreshData -> page 1

    expect(c.canLoadMoreProducts, isTrue);
    await c.loadMoreProducts();
    expect(c.products.map((p) => p.id), containsAll(<int>[1, 2]));
    expect(c.canLoadMoreProducts, isFalse);
    await c.loadMoreProducts(); // no-op past the end
    expect(products.fetchMoreCount, 1);
  });

  test('setProductSearch drops a stale response', () async {
    // Inline fake: completes the page for query 'a' only AFTER query 'b' is
    // issued, so AppController.setProductSearch's guard
    //   `if (productSearch != value) return;`
    // must discard the 'a' result and keep 'b'.
    final gate = Completer<void>();
    final repo = _StaleProductRepo(gate);
    final c = AppController(productRepository: repo);
    await c.loginAsRoleForTest(UserRole.manager);

    c.setProductSearch('a'); // in flight, blocked on gate
    c.setProductSearch('b'); // resolves immediately with [productB]
    gate.complete();         // now let 'a' resolve with [productA]
    await Future<void>.delayed(Duration.zero);

    expect(c.productSearch, 'b');
    expect(c.products.every((p) => p.name != 'A-STALE'), isTrue);
  });

  test('loadMoreCustomers appends and advances', () async {
    final customers = FakeCustomerRepository(
      pages: [const PagedCustomers(rows: [], nextCursor: 'k1')],
      morePages: [const PagedCustomers(rows: [], nextCursor: null)],
    );
    final c = AppController(customerRepository: customers);
    await c.loginAsRoleForTest(UserRole.manager);
    expect(c.canLoadMoreCustomers, isTrue);
    final more = await c.loadMoreCustomers();
    expect(more, isTrue);
    expect(c.canLoadMoreCustomers, isFalse);
  });
}

// Minimal inline fake for the stale-response test. Implement fetchProductPage
// so the FIRST call (query 'a') returns a Future gated on [gate] yielding a
// product named 'A-STALE'; the SECOND call (query 'b') returns immediately with
// a product named 'B'. Other methods can throw UnimplementedError.
class _StaleProductRepo implements ProductRepository {
  _StaleProductRepo(this._gate);
  final Completer<void> _gate;
  int _calls = 0;

  @override
  Future<PagedProducts> fetchProductPage({
    String? query,
    int? categoryId,
    int? locationId,
    String? stockFilter,
    String? cursor,
  }) async {
    _calls++;
    if (_calls == 1) {
      await _gate.future;
      return PagedProducts(rows: [Product(id: 91, name: 'A-STALE' /* ...required */)], nextCursor: null);
    }
    return PagedProducts(rows: [Product(id: 92, name: 'B' /* ...required */)], nextCursor: null);
  }

  @override
  Future<Product> upsertProduct(Product product) => throw UnimplementedError();
  @override
  Future<void> deleteProduct(int id) => throw UnimplementedError();
}
```

> Add `import 'dart:async';` at the top. Fill `Product(...)` required params from the real model. If `loginAsRoleForTest(UserRole.manager)` consumes the first `fetchProductPage` call before the test's own `setProductSearch('a')`, adjust `_calls` thresholds so the gated call is the first *search* call, not the first call overall.

- [ ] **Step 8: Write `test/app/app_controller_lifecycle_test.dart`**

```dart
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
    c.addToCart(c.products.first);
    await c.setReportRange(ReportRange.week, kind: 'all-transactions');
    c.logout();

    expect(c.isLoggedIn, isFalse);
    expect(c.selectedSection, AppSection.pos);
    expect(c.cartLines, isEmpty);
    expect(c.selectedCustomer, isNull);
    expect(c.productSearch, '');
    expect(c.selectedReportRange, ReportRange.today);
    expect(c.selectedGenericReport, 'purchases');
    expect(c.errorMessage, isNull);
  });

  test('checkout empties cart, clears customer, returns a transaction', () async {
    final c = AppController();
    await c.loginAsRoleForTest(UserRole.cashier);
    c.selectCustomer(c.customers.first);
    c.addToCart(c.products.first);
    final tx = await c.checkout();
    expect(tx, isNotNull);
    expect(c.cartLines, isEmpty);
    expect(c.selectedCustomer, isNull);
  });

  test('checkout returns null with empty cart', () async {
    final c = AppController();
    await c.loginAsRoleForTest(UserRole.cashier);
    expect(await c.checkout(), isNull);
  });
}
```

- [ ] **Step 9: Run the suite against the untouched AppController**

Run: `flutter test test/app/`
Expected: all PASS. If a test encodes a wrong assumption, fix the *test* to match today's behavior (characterization, not redesign) — except `discountAmount == 1800` / `grandTotal == 16200`, already locked by `widget_test.dart`.

- [ ] **Step 10: Full run**

Run: `flutter test`
Expected: `test/app/` + `test/widget_test.dart` all green.

- [ ] **Step 11: Commit**

```bash
git add test/app/
git commit -m "test: characterization suite for AppController before split"
```

---

## Task 2: `AsyncGuard`

Extract the busy-depth / error-capture plumbing. Pure internal move — no public behavior change, no call-site changes.

**Files:**
- Create: `lib/src/app/async_guard.dart`
- Modify: `lib/src/app/app_controller.dart`

**Interfaces:**
- Produces:
  ```dart
  class AsyncGuard extends ChangeNotifier {
    bool get isBusy;
    String? get errorMessage;
    Future<void> run(Future<void> Function() action);
    void reportError(Object error);
    void clearError();
  }
  ```

- [ ] **Step 1: Write `lib/src/app/async_guard.dart`**

```dart
import 'package:flutter/foundation.dart';

/// Owns "is something in flight" state plus the last error string. One
/// instance is shared by every controller so the busy/error plumbing is
/// defined exactly once (was `AppController._runBusy`).
class AsyncGuard extends ChangeNotifier {
  int _depth = 0;
  bool _isBusy = false;
  String? _errorMessage;

  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;

  /// Reentrant busy scope. First entrant flips [isBusy] true and clears the
  /// error; the last to leave flips it back. A throw is captured into
  /// [errorMessage] and swallowed (matches the pre-split `_runBusy`).
  Future<void> run(Future<void> Function() action) async {
    final wasIdle = _depth == 0;
    _depth++;
    if (wasIdle) {
      _isBusy = true;
      _errorMessage = null;
      notifyListeners();
    }
    try {
      await action();
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _depth--;
      if (_depth < 0) _depth = 0;
      if (_depth == 0) {
        _isBusy = false;
        notifyListeners();
      }
    }
  }

  void reportError(Object error) {
    _errorMessage = error.toString();
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
```

- [ ] **Step 2: Analyze the new file**

Run: `flutter analyze lib/src/app/async_guard.dart`
Expected: `No issues found!`

- [ ] **Step 3: Wire it into `AppController`** (`lib/src/app/app_controller.dart`)

1. Add `import 'async_guard.dart';`.
2. Add field `final AsyncGuard _guard = AsyncGuard();` and, in the constructor body, `_guard.addListener(notifyListeners);`.
3. Delete fields `bool isBusy = false;` (line 77), `String? errorMessage;` (78), `int _busyDepth = 0;` (79).
4. Add getters `bool get isBusy => _guard.isBusy;` and `String? get errorMessage => _guard.errorMessage;`.
5. Replace the whole `_runBusy` method (lines 1047-1067) with:
   ```dart
   Future<void> _runBusy(Future<void> Function() action) => _guard.run(action);
   ```
6. In `setProductSearch` (line 384) and `searchCustomers` (line 403): `errorMessage = error.toString();` → `_guard.reportError(error);` and delete the following `notifyListeners();`. In `logout` (line 306): `errorMessage = null;` → `_guard.clearError();`.
7. Add:
   ```dart
   @override
   void dispose() {
     _guard.removeListener(notifyListeners);
     _guard.dispose();
     super.dispose();
   }
   ```

- [ ] **Step 4: Analyze + test**

Run: `flutter analyze` → `No issues found!`
Run: `flutter test` → all green (no test changed).

- [ ] **Step 5: Commit**

```bash
git add lib/src/app/async_guard.dart lib/src/app/app_controller.dart
git commit -m "refactor: extract AsyncGuard from AppController busy/error plumbing"
```

---

## Task 3: `NavigationController`

Moves `selectedSection` + `selectSection`. `availableSections`, `canManage`, and the reports-loading side effect still live on `AppController`, so `NavigationController` reads them via injected callbacks.

**Files:**
- Create: `lib/src/app/controllers/navigation_controller.dart`
- Modify: `lib/src/app/app_controller.dart`, `lib/src/app/home_shell.dart` (3 sites), `test/widget_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class NavigationController extends ChangeNotifier {
    NavigationController({
      required bool Function(AppSection) canView,
      required void Function(AppSection) onEnterSection,
    });
    AppSection get selectedSection;
    void selectSection(AppSection section);
    void reset();
  }
  ```

- [ ] **Step 1: Write `lib/src/app/controllers/navigation_controller.dart`**

```dart
import 'package:flutter/foundation.dart';

import '../app_controller.dart' show AppSection;

class NavigationController extends ChangeNotifier {
  NavigationController({
    required bool Function(AppSection section) canView,
    required void Function(AppSection section) onEnterSection,
  })  : _canView = canView,
        _onEnterSection = onEnterSection;

  final bool Function(AppSection section) _canView;
  final void Function(AppSection section) _onEnterSection;

  AppSection _selectedSection = AppSection.pos;
  AppSection get selectedSection => _selectedSection;

  void selectSection(AppSection section) {
    if (!_canView(section)) return;
    if (_selectedSection == section) return;
    _selectedSection = section;
    notifyListeners();
    _onEnterSection(section);
  }

  void reset() {
    _selectedSection = AppSection.pos;
  }
}
```

> Pre-split `selectSection` checked `availableSections.contains(section)`. Since `availableSections == AppSection.values.where(canViewSection)`, `_canView(section)` is the exact per-section equivalent.

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/src/app/controllers/navigation_controller.dart` → `No issues found!`

- [ ] **Step 3: Wire into `AppController`**

1. `import 'controllers/navigation_controller.dart';`
2. Add field + build in the constructor body after `_guard.addListener(...)`:
   ```dart
   late final NavigationController navigation = NavigationController(
     canView: canViewSection,
     onEnterSection: (section) {
       if (section == AppSection.reports && canManage) {
         loadSalesReport(selectedReportRange);
         loadGenericReport('all-transactions');
         loadGenericReport('returns');
       }
     },
   );
   ```
   plus `navigation.addListener(notifyListeners);` in the ctor body and `navigation.removeListener(notifyListeners); navigation.dispose();` in `dispose()`.
3. Delete field `AppSection selectedSection = AppSection.pos;` (line 71).
4. Delete method `selectSection` (lines 352-362).
5. Add delegating getter `AppSection get selectedSection => navigation.selectedSection;`.
6. Internal writers: `login` (line 268) and `logout` (line 300) `selectedSection = AppSection.pos;` → `navigation.reset();`.

- [ ] **Step 4: Migrate `home_shell.dart`**

Run `grep -n "selectSection\|selectedSection" lib/src/app/home_shell.dart`. For each: `AppScope.of(context).selectSection(...)` → `AppScope.of(context).navigation.selectSection(...)`; `AppScope.of(context).selectedSection` → `AppScope.of(context).navigation.selectedSection`.

- [ ] **Step 5: Migrate `test/widget_test.dart`**

`controller.selectSection(AppSection.reports)` → `controller.navigation.selectSection(AppSection.reports)`; `controller.selectedSection` → `controller.navigation.selectedSection`.

- [ ] **Step 6: Analyze + test**

Run: `flutter analyze` → `No issues found!` (an unknown-getter error = a missed call site).
Run: `flutter test` → all green (`availableSections` test unaffected).

- [ ] **Step 7: Commit**

```bash
git add lib/src/app/controllers/navigation_controller.dart lib/src/app/app_controller.dart lib/src/app/home_shell.dart test/widget_test.dart
git commit -m "refactor: extract NavigationController from AppController"
```

---

## Task 4: `SessionController`

Moves user identity + all permission logic. Reads `/api/role-permissions` through a callback into `AppController`'s still-present `_featureRecords` map (that becomes a real `FeatureRecordController` reference in Task 7).

**Files:**
- Create: `lib/src/app/controllers/session_controller.dart`
- Modify: `lib/src/app/app_controller.dart`
- Modify: `lib/src/app/pos_kasir_app.dart` (1: `isLoggedIn`), `lib/src/auth/screens/login_screen.dart` (1), `lib/src/authorization/screens/authorization_screen.dart` (3), `lib/src/app/home_shell.dart`, and every screen reading `canManage`/`can*Menu`/`isAdministrator`/`currentUser`/`demoUsers`/`availableSections` (grep in Step 5).
- Modify: `test/app/app_controller_permissions_test.dart`.

**Note on `loginAsRoleForTest`:** the characterization suite and `widget_test.dart` call `controller.loginAsRoleForTest(role)`. Keep it as a thin delegating method **on `AppController`** (it delegates to `login`, an orchestration entry point). Only `authenticate` (the pure auth step) lives on `SessionController`.

**Interfaces:**
- Produces:
  ```dart
  class SessionController extends ChangeNotifier {
    SessionController({required List<FeatureRecord>? Function() rolePermissionRecords});
    List<AppUser> get demoUsers;
    AppUser? get currentUser;
    bool get isLoggedIn;
    bool get isManager;
    bool get isAdministrator;
    bool get canManage;
    bool canViewSection(AppSection section);
    bool canViewMenu(String section);
    bool canCreateMenu(String section);
    bool canUpdateMenu(String section);
    bool canDeleteMenu(String section);
    List<AppSection> get availableSections;
    Future<void> authenticate(AuthRepository repo, {required String username, required String password});
    void reset();
  }
  ```

- [ ] **Step 1: Write `lib/src/app/controllers/session_controller.dart`**

Move verbatim from `app_controller.dart`: `demoUsers` (64-68), `currentUser` (70), `isLoggedIn`/`isManager`/`isAdministrator`/`canManage` (112-115), `availableSections` (121-131), `canViewSection` (133-150), `canViewMenu` (152-168), `canCreateMenu`/`canUpdateMenu`/`canDeleteMenu` (170-172), `_canCrud` (174-185), `_rolePermission` (187-199). In `canViewMenu`, `_canCrud`, and `_rolePermission`, replace `_featureRecords['/api/role-permissions']` with `_rolePermissionRecords()`.

```dart
import 'package:flutter/foundation.dart';

import '../../auth/models/app_user.dart';
import '../../auth/repositories/auth_repository.dart';
import '../../shared/models/feature_record.dart';
import '../app_controller.dart' show AppSection;

class SessionController extends ChangeNotifier {
  SessionController({required List<FeatureRecord>? Function() rolePermissionRecords})
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
      AppSection.master => canViewMenu('inventory') ||
          canViewMenu('customers') ||
          canViewMenu('suppliers'),
      AppSection.users => canViewMenu('users') ||
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
      UserRole.manager => !{'users', 'roles', 'authorization'}.contains(section),
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
        .where((record) =>
            record.values['role'] == role && record.values['section'] == section)
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
```

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/src/app/controllers/session_controller.dart` → `No issues found!`

- [ ] **Step 3: Wire into `AppController`**

1. `import 'controllers/session_controller.dart';`
2. Build (must come before `navigation`, which passes `canViewSection`):
   ```dart
   late final SessionController session = SessionController(
     rolePermissionRecords: () => _featureRecords['/api/role-permissions'],
   );
   ```
   `session.addListener(notifyListeners);` in ctor; remove+dispose in `dispose()`.
3. Delete the moved fields/methods listed in Step 1.
4. Add delegating getters for internal callers still in `app_controller.dart`:
   ```dart
   AppUser? get currentUser => session.currentUser;
   bool get isLoggedIn => session.isLoggedIn;
   bool get canManage => session.canManage;
   bool canViewSection(AppSection s) => session.canViewSection(s);
   ```
5. In `login` (line 264) replace
   `currentUser = await _authRepository.login(username: username, password: password);`
   with
   `await session.authenticate(_authRepository, username: username, password: password);`
6. In `logout` (line 299) replace `currentUser = null;` with `session.reset();`.
7. Keep `loginAsRoleForTest` unchanged.

- [ ] **Step 4: Migrate `pos_kasir_app.dart`, `login_screen.dart`, `authorization_screen.dart`**

- `pos_kasir_app.dart:29` `!_controller.isLoggedIn` → `!_controller.session.isLoggedIn`.
- In each screen: `.canManage` → `.session.canManage`; `.canCreateMenu(` → `.session.canCreateMenu(`; `.canUpdateMenu(` → `.session.canUpdateMenu(`; `.canDeleteMenu(` → `.session.canDeleteMenu(`; `.canViewMenu(` → `.session.canViewMenu(`; `.isAdministrator` → `.session.isAdministrator`; `.isManager` → `.session.isManager`; `.currentUser` → `.session.currentUser`; `.demoUsers` → `.session.demoUsers`; `.availableSections` → `.session.availableSections`; `.canViewSection(` → `.session.canViewSection(`.

- [ ] **Step 5: Sweep every remaining screen**

```bash
grep -rn "AppScope.of(context)\.\(canManage\|canViewMenu\|canCreateMenu\|canUpdateMenu\|canDeleteMenu\|canViewSection\|isAdministrator\|isManager\|isLoggedIn\|currentUser\|demoUsers\|availableSections\)" lib/
```
Namespace every hit with `.session`. Include `home_shell.dart` (renders nav from `availableSections`).

- [ ] **Step 6: Migrate tests**

`test/app/app_controller_permissions_test.dart`: `c.canViewSection` → `c.session.canViewSection`; `c.canCreateMenu` → `c.session.canCreateMenu`; `c.canViewMenu` → `c.session.canViewMenu`; `c.availableSections` → `c.session.availableSections`. (`c.loginAsRoleForTest` stays.)
`test/widget_test.dart`: no change.

- [ ] **Step 7: Analyze + test**

Run: `flutter analyze` → `No issues found!`
Run: `flutter test` → all green.

- [ ] **Step 8: Commit**

```bash
git add lib/src/app/controllers/session_controller.dart lib/src/app/app_controller.dart lib/src/auth/screens/login_screen.dart lib/src/authorization/screens/authorization_screen.dart lib/src/app/pos_kasir_app.dart lib/src/app/home_shell.dart lib/src/pos/screens/pos_screen.dart lib/src/inventory/screens/inventory_screen.dart lib/src/customers/screens/customer_screen.dart lib/src/purchases/screens/purchase_screen.dart lib/src/reports/screens/reports_screen.dart lib/src/returns/screens/returns_screen.dart lib/src/shared/widgets/feature_table_screen.dart test/app/app_controller_permissions_test.dart
git commit -m "refactor: extract SessionController from AppController"
```

---

## Task 5: `ProductController`

Moves the product list, cursor, search, three filters, and load/loadMore/save/delete.

**Naming:** the field on `AppController` is `products` (a `ProductController`); its list getter is **`items`** (`controller.products.items`) to avoid `products.products`.

**Files:**
- Create: `lib/src/app/controllers/product_controller.dart`
- Modify: `lib/src/app/app_controller.dart`, `lib/src/inventory/screens/inventory_screen.dart` (8), `test/widget_test.dart`, `test/app/app_controller_cart_test.dart`, `test/app/app_controller_paging_test.dart`

**Interfaces:**
- Consumes: `AsyncGuard`, `ProductRepository`.
- Produces:
  ```dart
  class ProductController extends ChangeNotifier {
    ProductController(AsyncGuard guard, ProductRepository repo, {List<Product> initialItems});
    List<Product> get items;
    bool get canLoadMore;
    String get search;
    int? get categoryFilterId;
    int? get locationFilterId;
    String get stockFilter;
    void setSearch(String value);
    Future<void> setCategoryFilter(int? id);
    Future<void> setLocationFilter(int? id);
    Future<void> setStockFilter(String f);
    Future<void> loadMore();
    Future<Product?> save(Product p);
    Future<void> remove(Product p);
    Future<void> reload();
    void reset();
  }
  ```

- [ ] **Step 1: Write `lib/src/app/controllers/product_controller.dart`**

```dart
import 'package:flutter/foundation.dart';

import '../../inventory/models/product.dart';
import '../../inventory/repositories/product_repository.dart';
import '../async_guard.dart';

class ProductController extends ChangeNotifier {
  ProductController(this._guard, this._repo, {List<Product> initialItems = const []})
      : _items = initialItems;

  final AsyncGuard _guard;
  final ProductRepository _repo;

  List<Product> _items;
  String? _nextCursor;
  String _search = '';
  int? _categoryFilterId;
  int? _locationFilterId;
  String _stockFilter = 'all';

  List<Product> get items => List<Product>.from(_items);
  bool get canLoadMore => _nextCursor != null;
  String get search => _search;
  int? get categoryFilterId => _categoryFilterId;
  int? get locationFilterId => _locationFilterId;
  String get stockFilter => _stockFilter;

  String? get _stockFilterArg => _stockFilter == 'all' ? null : _stockFilter;

  void setSearch(String value) {
    _search = value;
    _nextCursor = null;
    notifyListeners();
    _repo
        .fetchProductPage(
          query: value,
          categoryId: _categoryFilterId,
          locationId: _locationFilterId,
          stockFilter: _stockFilterArg,
        )
        .then((page) {
          if (_search != value) return;
          _items = page.rows;
          _nextCursor = page.nextCursor;
          notifyListeners();
        })
        .catchError((Object error) {
          _guard.reportError(error);
        });
  }

  Future<void> setCategoryFilter(int? id) async {
    _categoryFilterId = id;
    await _guard.run(_loadPage);
  }

  Future<void> setLocationFilter(int? id) async {
    _locationFilterId = id;
    await _guard.run(_loadPage);
  }

  Future<void> setStockFilter(String filter) async {
    _stockFilter = filter;
    await _guard.run(_loadPage);
  }

  Future<void> loadMore() async {
    final cursor = _nextCursor;
    if (cursor == null) return;
    await _guard.run(() async {
      final page = await _repo.fetchProductPage(
        query: _search,
        categoryId: _categoryFilterId,
        locationId: _locationFilterId,
        stockFilter: _stockFilterArg,
        cursor: cursor,
      );
      _items = [..._items, ...page.rows];
      _nextCursor = page.nextCursor;
    });
  }

  Future<Product?> save(Product product) async {
    Product? saved;
    await _guard.run(() async {
      saved = await _repo.upsertProduct(product);
      await _loadPage();
    });
    return saved;
  }

  Future<void> remove(Product product) async {
    await _guard.run(() async {
      await _repo.deleteProduct(product.id);
      await _loadPage();
    });
  }

  Future<void> reload() => _guard.run(_loadPage);

  Future<void> _loadPage() async {
    final page = await _repo.fetchProductPage(
      query: _search,
      categoryId: _categoryFilterId,
      locationId: _locationFilterId,
      stockFilter: _stockFilterArg,
    );
    _items = page.rows;
    _nextCursor = page.nextCursor;
  }

  void reset() {
    _items = const [];
    _nextCursor = null;
    _search = '';
    _categoryFilterId = null;
    _locationFilterId = null;
    _stockFilter = 'all';
    notifyListeners();
  }
}
```

> `_loadPage` does not `notifyListeners()` itself — it always runs inside `_guard.run`, whose exit notifies (matches pre-split `_loadProductPage` + `_runBusy`).

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/src/app/controllers/product_controller.dart` → `No issues found!`

- [ ] **Step 3: Wire into `AppController`**

1. `import 'controllers/product_controller.dart';`
2. The pre-split constructor seeds `_products = List.unmodifiable(dataStore.products);`. Keep the seed: in the constructor body (which still has `dataStore` in scope, lines 31-42) assign a plain field, or pass it through. Simplest: make `products` a plain `final` set in the constructor body:
   ```dart
   // in the field list:
   late final ProductController products;
   // in the constructor body, after dataStore is built:
   products = ProductController(_guard, _productRepository, initialItems: dataStore.products);
   products.addListener(notifyListeners);
   ```
   Remove+dispose in `dispose()`.
3. Delete from `app_controller.dart`: `_products` (99), `_productNextCursor` (106), `productSearch` (73), `selectedProductCategoryFilterId`/`selectedProductLocationFilterId`/`selectedProductStockFilter` (74-76), `products` getter (117), `filteredProducts` getter (201-203), `setProductSearch` (364-387), `saveProduct` (444-451), `deleteProduct` (453-458), `canLoadMoreProducts` (734), `setProductCategoryFilter`/`setProductLocationFilter`/`setProductStockFilter` (737-750), `loadMoreProducts` (752-768), `_loadProductPage` (1028-1039).
4. Update internal readers still in `app_controller.dart`:
   - `cartLines` (209): `_products.where(...)` → `products.items.where(...)`.
   - `checkout` (495): `await _loadProductPage();` → `await products.reload();`.
   - `refreshData` (528): `await _loadProductPage();` → `await products.reload();`.
   - `saveFeatureRecord` (864): `await _loadProductPage();` → `await products.reload();`.
   - `logout` (302-305, 323, 330): product field resets → `products.reset();`.

- [ ] **Step 4: Migrate `inventory_screen.dart`**

`grep -n "AppScope.of(context)" lib/src/inventory/screens/inventory_screen.dart` and follow the member reads. Map:
`.products` → `.products.items`; `.filteredProducts` → `.products.items`; `.setProductSearch(` → `.products.setSearch(`; `.saveProduct(` → `.products.save(`; `.deleteProduct(` → `.products.remove(`; `.canLoadMoreProducts` → `.products.canLoadMore`; `.loadMoreProducts(` → `.products.loadMore(`; `.setProductCategoryFilter(` → `.products.setCategoryFilter(`; `.setProductLocationFilter(` → `.products.setLocationFilter(`; `.setProductStockFilter(` → `.products.setStockFilter(`; `.selectedProductCategoryFilterId` → `.products.categoryFilterId`; `.selectedProductLocationFilterId` → `.products.locationFilterId`; `.selectedProductStockFilter` → `.products.stockFilter`; `.productSearch` → `.products.search`.
Also sweep other screens: `grep -rn "AppScope.of(context)\.\(products\|filteredProducts\|productSearch\)" lib/` (pos_screen reads `.products`).

- [ ] **Step 5: Migrate tests**

`test/widget_test.dart`: `controller.products.first` → `controller.products.items.first` (tests 3 and 4).
`test/app/app_controller_cart_test.dart`: `c.products` → `c.products.items`.
`test/app/app_controller_paging_test.dart`: `c.products` → `c.products.items`; `c.canLoadMoreProducts` → `c.products.canLoadMore`; `c.loadMoreProducts()` → `c.products.loadMore()`; `c.productSearch` → `c.products.search`; `c.setProductSearch(` → `c.products.setSearch(`. `products.fetchMoreCount` (fake) unchanged.

- [ ] **Step 6: Analyze + test**

Run: `flutter analyze` → `No issues found!`
Run: `flutter test` → all green.

- [ ] **Step 7: Commit**

```bash
git add lib/src/app/controllers/product_controller.dart lib/src/app/app_controller.dart lib/src/inventory/screens/inventory_screen.dart lib/src/pos/screens/pos_screen.dart test/widget_test.dart test/app/
git commit -m "refactor: extract ProductController from AppController"
```

---

## Task 6: `CustomerController`

Same shape as Task 5. Owns `selected` (was `selectedCustomer`).

**Files:**
- Create: `lib/src/app/controllers/customer_controller.dart`
- Modify: `lib/src/app/app_controller.dart`, `lib/src/customers/screens/customer_screen.dart` (7), `lib/src/pos/screens/pos_screen.dart`, `test/widget_test.dart`, `test/app/app_controller_cart_test.dart`, `test/app/app_controller_paging_test.dart`, `test/app/app_controller_lifecycle_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class CustomerController extends ChangeNotifier {
    CustomerController(AsyncGuard guard, CustomerRepository repo, {List<Customer> initialItems});
    List<Customer> get items;
    bool get canLoadMore;
    Customer? get selected;
    void select(Customer? customer);
    Future<void> search(String value);
    Future<bool> loadMore({String? query});
    Future<Customer?> save(Customer c);
    Future<void> remove(Customer c);
    Future<void> reload();
    void reset();
  }
  ```

- [ ] **Step 1: Write `lib/src/app/controllers/customer_controller.dart`**

```dart
import 'package:flutter/foundation.dart';

import '../../customers/models/customer.dart';
import '../../customers/repositories/customer_repository.dart';
import '../async_guard.dart';

class CustomerController extends ChangeNotifier {
  CustomerController(this._guard, this._repo, {List<Customer> initialItems = const []})
      : _items = initialItems;

  final AsyncGuard _guard;
  final CustomerRepository _repo;

  List<Customer> _items;
  String? _nextCursor;
  Customer? _selected;

  List<Customer> get items => List.unmodifiable(_items);
  bool get canLoadMore => _nextCursor != null;
  Customer? get selected => _selected;

  void select(Customer? customer) {
    _selected = customer;
    notifyListeners();
  }

  Future<void> search(String value) async {
    try {
      _nextCursor = null;
      notifyListeners();
      final page = await _repo.fetchCustomerPage(query: value);
      _items = page.rows;
      _nextCursor = page.nextCursor;
      notifyListeners();
    } catch (error) {
      _guard.reportError(error);
    }
  }

  Future<bool> loadMore({String? query}) async {
    final cursor = _nextCursor;
    if (cursor == null) return false;
    await _guard.run(() async {
      final page = await _repo.fetchCustomerPage(query: query, cursor: cursor);
      _items = [..._items, ...page.rows];
      _nextCursor = page.nextCursor;
    });
    return true;
  }

  Future<Customer?> save(Customer customer) async {
    Customer? saved;
    await _guard.run(() async {
      saved = await _repo.upsertCustomer(customer);
      await _loadPage();
      if (_selected?.id == saved?.id) _selected = saved;
    });
    return saved;
  }

  Future<void> remove(Customer customer) async {
    await _guard.run(() async {
      await _repo.deleteCustomer(customer.id);
      await _loadPage();
      if (_selected?.id == customer.id) _selected = null;
    });
  }

  Future<void> reload() => _guard.run(_loadPage);

  Future<void> _loadPage({String? query}) async {
    final page = await _repo.fetchCustomerPage(query: query);
    _items = page.rows;
    _nextCursor = page.nextCursor;
  }

  void reset() {
    _items = const [];
    _nextCursor = null;
    _selected = null;
    notifyListeners();
  }
}
```

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/src/app/controllers/customer_controller.dart` → `No issues found!`

- [ ] **Step 3: Wire into `AppController`**

1. `import 'controllers/customer_controller.dart';`
2. Build in the constructor body (seed like products): `customers = CustomerController(_guard, _customerRepository, initialItems: dataStore.customers);` `customers.addListener(notifyListeners);` + dispose. Field: `late final CustomerController customers;`.
3. Delete from `app_controller.dart`: `_customers` (100), `_customerNextCursor` (107), `selectedCustomer` (72), `customers` getter (118), `selectCustomer` (389-392), `searchCustomers` (394-406), `saveCustomer` (460-470), `deleteCustomer` (472-478), `canLoadMoreCustomers` (735), `loadMoreCustomers` (770-782), `_loadCustomerPage` (1041-1045).
4. Update internal readers:
   - `discountAmount` (222) and `discountRateForProduct` (243): `selectedCustomer` → `customers.selected`.
   - `checkout` (487, 496, 499, 504): `selectedCustomer` → `customers.selected`; `await _loadCustomerPage();` → `await customers.reload();`; `_customers` (fetchTransactions arg) → `customers.items`; `selectedCustomer = null;` → `customers.select(null);`.
   - `refreshData` (529, 532): `await _loadCustomerPage();` → `await customers.reload();`; `_customers` → `customers.items`.
   - `login` (269): `selectedCustomer = null;` → `customers.select(null);`.
   - `logout`: customer field resets → `customers.reset();`.

- [ ] **Step 4: Migrate `customer_screen.dart` + sweep**

`.customers` → `.customers.items`; `.selectCustomer(` → `.customers.select(`; `.searchCustomers(` → `.customers.search(`; `.saveCustomer(` → `.customers.save(`; `.deleteCustomer(` → `.customers.remove(`; `.canLoadMoreCustomers` → `.customers.canLoadMore`; `.loadMoreCustomers(` → `.customers.loadMore(`; `.selectedCustomer` → `.customers.selected`.
```bash
grep -rn "AppScope.of(context)\.\(customers\|selectedCustomer\|selectCustomer\|searchCustomers\|loadMoreCustomers\|canLoadMoreCustomers\|saveCustomer\|deleteCustomer\)" lib/
```
(`pos_screen.dart` reads `selectedCustomer` and `customers`.)

- [ ] **Step 5: Migrate tests**

`test/widget_test.dart`: `controller.customers.first` → `controller.customers.items.first`; `controller.selectCustomer(` → `controller.customers.select(`.
`test/app/app_controller_cart_test.dart`: `c.customers` → `c.customers.items`; `c.selectCustomer(` → `c.customers.select(`.
`test/app/app_controller_paging_test.dart`: `c.canLoadMoreCustomers` → `c.customers.canLoadMore`; `c.loadMoreCustomers()` → `c.customers.loadMore()`.
`test/app/app_controller_lifecycle_test.dart`: `c.customers.first` → `c.customers.items.first`; `c.selectCustomer(` → `c.customers.select(`; `c.selectedCustomer` → `c.customers.selected`.

- [ ] **Step 6: Analyze + test**

Run: `flutter analyze` → `No issues found!`
Run: `flutter test` → all green.

- [ ] **Step 7: Commit**

```bash
git add lib/src/app/controllers/customer_controller.dart lib/src/app/app_controller.dart lib/src/customers/screens/customer_screen.dart lib/src/pos/screens/pos_screen.dart test/widget_test.dart test/app/
git commit -m "refactor: extract CustomerController from AppController"
```

---

## Task 7: `FeatureRecordController`

Moves the keyed master-data cache, its load/loadMore/save/delete, the generic-report loaders built on it, `_invalidateReports`, `_queryKey`. `_reportQuery` / range helpers / `exportSalesReport` **stay on `AppController` until Task 8** because they read report filter state; `FeatureRecordController.loadGenericReport` takes the assembled query map as a parameter.

**Files:**
- Create: `lib/src/app/controllers/feature_record_controller.dart`
- Modify: `lib/src/app/app_controller.dart`, `lib/src/shared/widgets/feature_table_screen.dart` (7), `lib/src/purchases/screens/purchase_screen.dart` (6), `lib/src/returns/screens/returns_screen.dart`, `lib/src/customers/screens/customer_screen.dart`, `lib/src/reports/screens/reports_screen.dart`
- Modify: `test/app/app_controller_lifecycle_test.dart`

**Interfaces:**
- Consumes: `AsyncGuard`, `FeatureRepository`, a `ProductController` reference (for `save`'s product-reload side effect), and `void Function() onReportsInvalidated` (no-op until Task 8).
- Produces:
  ```dart
  class FeatureRecordController extends ChangeNotifier {
    FeatureRecordController(AsyncGuard guard, FeatureRepository repo, {
      required ProductController products,
      required void Function() onReportsInvalidated,
    });
    String get selectedGenericReport;
    List<FeatureRecord> records(String path);
    List<FeatureRecord> get customerGroupDiscounts;
    bool canLoadMore(String path, {Map<String, String>? query});
    Future<void> load(String path, {Map<String, String>? query, bool force = false});
    Future<void> loadMore(String path, {Map<String, String>? query});
    Future<FeatureRecord?> save(String path, Map<String, Object?> body, {int? id});
    Future<void> saveCustomerGroupDiscounts(List<Map<String, Object?>> items, {List<int> deleteIds});
    Future<void> remove(String path, FeatureRecord record);
    Future<List<FeatureRecord>> loadGenericReport(String kind, Map<String, String> query);
    Future<void> loadMoreGenericReport(String kind, Map<String, String> query);
    Future<List<int>?> exportGenericReport(String kind, Map<String, String> query);
    void invalidateReports();
    void reset();
  }
  ```

- [ ] **Step 1: Write `lib/src/app/controllers/feature_record_controller.dart`**

```dart
import 'package:flutter/foundation.dart';

import '../../shared/models/feature_record.dart';
import '../../shared/repositories/feature_repository.dart';
import '../async_guard.dart';
import 'product_controller.dart';

class FeatureRecordController extends ChangeNotifier {
  FeatureRecordController(
    this._guard,
    this._repo, {
    required ProductController products,
    required void Function() onReportsInvalidated,
  })  : _products = products,
        _onReportsInvalidated = onReportsInvalidated;

  final AsyncGuard _guard;
  final FeatureRepository _repo;
  final ProductController _products;
  final void Function() _onReportsInvalidated;

  final Map<String, List<FeatureRecord>> _records = {};
  final Map<String, String> _queryKeys = {};
  final Map<String, String?> _nextCursors = {};
  final Map<String, Future<void>> _loadFutures = {};
  String _selectedGenericReport = 'purchases';

  String get selectedGenericReport => _selectedGenericReport;

  List<FeatureRecord> records(String path) =>
      List.unmodifiable(_records[path] ?? const []);

  List<FeatureRecord> get customerGroupDiscounts =>
      records('/api/customer-group-discounts');

  bool canLoadMore(String path, {Map<String, String>? query}) {
    if (_nextCursors[path] == null) return false;
    if (query == null) return true;
    return _queryKeys[path] == _queryKey(query);
  }

  Future<void> load(String path,
      {Map<String, String>? query, bool force = false}) async {
    final cacheKey = _queryKey(query);
    if (!force &&
        _records.containsKey(path) &&
        _queryKeys[path] == cacheKey) {
      return;
    }
    final loadKey = '$path?$cacheKey';
    final existingLoad = _loadFutures[loadKey];
    if (existingLoad != null) {
      await existingLoad;
      return;
    }
    late Future<void> load;
    load = _guard.run(() async {
      final page = await _repo.listPage(path, query: query);
      _records[path] = page.rows;
      _nextCursors[path] = page.nextCursor;
      _queryKeys[path] = cacheKey;
    });
    _loadFutures[loadKey] = load;
    try {
      await load;
    } finally {
      _loadFutures.remove(loadKey);
    }
  }

  Future<void> loadMore(String path, {Map<String, String>? query}) async {
    final cursor = _nextCursors[path];
    if (cursor == null) return;
    final nextQuery = {...?query, 'cursor': cursor};
    final baseCacheKey = _queryKey(query);
    final loadKey = '$path?more:${_queryKey(nextQuery)}';
    final existingLoad = _loadFutures[loadKey];
    if (existingLoad != null) {
      await existingLoad;
      return;
    }
    late Future<void> load;
    load = _guard.run(() async {
      final page = await _repo.listPage(path, query: nextQuery);
      final current = _records[path] ?? const <FeatureRecord>[];
      _records[path] = [...current, ...page.rows];
      _nextCursors[path] = page.nextCursor;
      _queryKeys[path] = baseCacheKey;
    });
    _loadFutures[loadKey] = load;
    try {
      await load;
    } finally {
      _loadFutures.remove(loadKey);
    }
  }

  Future<FeatureRecord?> save(String path, Map<String, Object?> body, {int? id}) async {
    FeatureRecord? saved;
    await _guard.run(() async {
      saved = await _repo.save(path, body, id: id);
      final page = await _repo.listPage(path);
      _records[path] = page.rows;
      _nextCursors[path] = page.nextCursor;
      _queryKeys[path] = _queryKey(null);
      if (path.contains('purchases') ||
          path.contains('returns') ||
          path == '/api/stock' ||
          path == '/api/cash-entries') {
        await _products.reload();
        invalidateReports();
      }
    });
    return saved;
  }

  Future<void> saveCustomerGroupDiscounts(
    List<Map<String, Object?>> items, {
    List<int> deleteIds = const [],
  }) async {
    await _guard.run(() async {
      await _repo.saveBatch('/api/customer-group-discounts', items, deleteIds: deleteIds);
      final page = await _repo.listPage('/api/customer-group-discounts');
      _records['/api/customer-group-discounts'] = page.rows;
      _nextCursors['/api/customer-group-discounts'] = page.nextCursor;
      _queryKeys['/api/customer-group-discounts'] = _queryKey(null);
    });
  }

  Future<void> remove(String path, FeatureRecord record) async {
    await _guard.run(() async {
      await _repo.delete(path, record.id);
      final page = await _repo.listPage(path);
      _records[path] = page.rows;
      _nextCursors[path] = page.nextCursor;
      _queryKeys[path] = _queryKey(null);
      invalidateReports();
    });
  }

  Future<List<FeatureRecord>> loadGenericReport(
      String kind, Map<String, String> query) async {
    _selectedGenericReport = kind;
    final path = '/api/reports/$kind';
    await load(path, query: query);
    return records(path);
  }

  Future<void> loadMoreGenericReport(String kind, Map<String, String> query) =>
      loadMore('/api/reports/$kind', query: query);

  Future<List<int>?> exportGenericReport(String kind, Map<String, String> query) async {
    List<int>? bytes;
    await _guard.run(() async {
      bytes = await _repo.exportReport(kind, query);
    });
    return bytes;
  }

  void invalidateReports() {
    final reportPaths = _records.keys
        .where((path) => path.startsWith('/api/reports/'))
        .toList(growable: false);
    for (final path in reportPaths) {
      _records.remove(path);
      _queryKeys.remove(path);
      _nextCursors.remove(path);
    }
    _onReportsInvalidated();
  }

  String _queryKey(Map<String, String>? query) {
    if (query == null || query.isEmpty) return '';
    final keys = query.keys.toList()..sort();
    return keys.map((key) => '$key=${query[key]}').join('&');
  }

  void reset() {
    _records.clear();
    _queryKeys.clear();
    _nextCursors.clear();
    _loadFutures.clear();
    _selectedGenericReport = 'purchases';
    notifyListeners();
  }
}
```

> Shadowing note: the inner `late Future<void> load;` shadows the method `load` — this matches the pre-split code (`app_controller.dart:803`). Keep it to minimize diff; rename to `loadFuture` if `flutter analyze` complains (it does not today).

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/src/app/controllers/feature_record_controller.dart` → `No issues found!`

- [ ] **Step 3: Wire into `AppController`**

1. `import 'controllers/feature_record_controller.dart';`
2. Build AFTER `products`, BEFORE `session` (session's callback reads it):
   ```dart
   featureRecords = FeatureRecordController(
     _guard,
     _featureRepository,
     products: products,
     onReportsInvalidated: () {},
   );
   featureRecords.addListener(notifyListeners);
   ```
   Field: `late final FeatureRecordController featureRecords;`. Remove+dispose in `dispose()`.
3. Repoint `SessionController`'s callback: `rolePermissionRecords: () => featureRecords.records('/api/role-permissions'),` and ensure `featureRecords` is constructed before `session`.
4. Delete from `app_controller.dart`: `_featureRecords`/`_featureQueryKeys`/`_featureNextCursors`/`_featureLoadFutures` (102-105), `featureRecords` method (724-726), `customerGroupDiscounts` getter (239-240), `canLoadMoreFeatureRecords` (728-732), `loadFeatureRecords` (784-816), `loadMoreFeatureRecords` (818-846), `saveFeatureRecord` (848-869), `saveCustomerGroupDiscounts` (871-888), `deleteFeatureRecord` (890-899), `_queryKey` (1011-1015), `_invalidateReports` (1017-1026).
5. Rewrite the generic-report wrappers (kept on `AppController`, still using the still-present `_reportQuery`):
   ```dart
   Future<List<FeatureRecord>> loadGenericReport(String kind, {String? search}) =>
       featureRecords.loadGenericReport(kind, _reportQuery(kind: kind, search: search));
   Future<void> loadMoreGenericReport(String kind, {String? search}) =>
       featureRecords.loadMoreGenericReport(kind, _reportQuery(kind: kind, search: search));
   Future<List<int>?> exportGenericReport(String kind, {String? search}) =>
       featureRecords.exportGenericReport(kind, _reportQuery(kind: kind, search: search));
   ```
6. `selectedGenericReport` field (95) → delegating getter `String get selectedGenericReport => featureRecords.selectedGenericReport;`. (`loadGenericReport` in `FeatureRecordController` sets it.)
7. Internal readers: `login` (275-278) `loadFeatureRecords(...)` → `featureRecords.load(...)`; `discountRateForProduct` (245) `customerGroupDiscounts` → `featureRecords.customerGroupDiscounts`; `checkout` (501) `_invalidateReports();` → `featureRecords.invalidateReports();`; `logout` feature-map clears → `featureRecords.reset();`.
8. `AppScope.of(context).featureRecords('/api/x')` (method) → `.featureRecords.records('/api/x')` (field) — Step 4.

- [ ] **Step 4: Migrate screens**

```bash
grep -rn "AppScope.of(context)\.\(featureRecords\|loadFeatureRecords\|loadMoreFeatureRecords\|canLoadMoreFeatureRecords\|saveFeatureRecord\|deleteFeatureRecord\|saveCustomerGroupDiscounts\|customerGroupDiscounts\)" lib/
```
`.featureRecords(` → `.featureRecords.records(`; `.loadFeatureRecords(` → `.featureRecords.load(`; `.loadMoreFeatureRecords(` → `.featureRecords.loadMore(`; `.canLoadMoreFeatureRecords(` → `.featureRecords.canLoadMore(`; `.saveFeatureRecord(` → `.featureRecords.save(`; `.deleteFeatureRecord(` → `.featureRecords.remove(`; `.saveCustomerGroupDiscounts(` → `.featureRecords.saveCustomerGroupDiscounts(`; `.customerGroupDiscounts` → `.featureRecords.customerGroupDiscounts`. Leave `.loadGenericReport(` / `.loadMoreGenericReport(` / `.exportGenericReport(` / `.selectedGenericReport` untouched (still on `AppController`).

- [ ] **Step 5: Migrate tests**

`test/app/app_controller_lifecycle_test.dart`: `c.featureRecords('/api/product-categories')` → `c.featureRecords.records('/api/product-categories')`; `c.customerGroupDiscounts` → `c.featureRecords.customerGroupDiscounts`.

- [ ] **Step 6: Analyze + test**

Run: `flutter analyze` → `No issues found!`
Run: `flutter test` → all green.

- [ ] **Step 7: Commit**

```bash
git add lib/src/app/controllers/feature_record_controller.dart lib/src/app/app_controller.dart lib/src/shared/widgets/feature_table_screen.dart lib/src/purchases/screens/purchase_screen.dart lib/src/returns/screens/returns_screen.dart lib/src/customers/screens/customer_screen.dart lib/src/reports/screens/reports_screen.dart test/app/
git commit -m "refactor: extract FeatureRecordController from AppController"
```

---

## Task 8: `ReportController` + `ReportFilterState`, then `CartController`, then final shell

Three sub-deliverables, each its own commit.

### 8a — `ReportFilterState` + `ReportController`

Collapses `selectedReport*` / `selectedReturnReport*` into two `ReportFilterState` instances; moves all report logic into `ReportController`.

**Files:**
- Create: `lib/src/app/controllers/report_filter_state.dart`, `lib/src/app/controllers/report_controller.dart`
- Modify: `lib/src/app/app_controller.dart`, `lib/src/reports/screens/reports_screen.dart` (9), `lib/src/returns/screens/returns_screen.dart` (13), `test/app/app_controller_reports_test.dart`, `test/app/app_controller_lifecycle_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class ReportFilterState {
    ReportRange range;         // = ReportRange.today
    DateTimeRange? customRange;
    int? productId;
    int? categoryId;
    int? customerId;
    int? supplierId;
    String type;               // = 'all'
    void reset();
  }
  class ReportController extends ChangeNotifier {
    ReportController(AsyncGuard guard, ReportRepository reportRepo, TransactionRepository txRepo, {
      required bool Function() canManage,
      required List<Customer> Function() customers,
      required Future<void> Function(String kind, {String? search}) loadGenericReport,
      required Future<void> Function(String kind, {String? search}) loadMoreGenericReport,
    });
    final ReportFilterState report;
    final ReportFilterState returnReport;
    SalesReport get salesReport;
    List<SaleTransaction> get transactions;
    ReportFilterState filterFor(String kind);
    ReportRange reportRangeFor(String kind);
    DateTimeRange? customReportRangeFor(String kind);
    Map<String, String> reportQuery({String? kind, String? search});
    Future<void> loadSalesReport(ReportRange range);
    Future<void> setRange(ReportRange range, {required String kind});
    Future<void> setCustomRange(DateTimeRange range, {String kind});
    Future<void> setProductFilter(int? id, {String kind});
    Future<void> setCategoryFilter(int? id, {String kind});
    Future<void> setCustomerFilter(int? id, {String kind});
    Future<void> setSupplierFilter(int? id, {String kind});
    Future<void> setCombinedType(String type);
    Future<void> setReturnType(String type);
    Future<List<int>?> exportSalesReport();
    Future<void> refetchTransactions(AppUser user);
    Future<void> refetchSalesReportIfManager();
    void reset();
  }
  ```

- [ ] **Step 1: Write `lib/src/app/controllers/report_filter_state.dart`**

```dart
import 'package:flutter/material.dart' show DateTimeRange;

import '../../reports/repositories/report_repository.dart' show ReportRange;

/// One report panel's range + filter selection. The app has two: the main
/// sales/purchase report and the returns report. Pre-split these were ~20
/// duplicated `selectedReport*` / `selectedReturnReport*` fields.
class ReportFilterState {
  ReportRange range = ReportRange.today;
  DateTimeRange? customRange;
  int? productId;
  int? categoryId;
  int? customerId;
  int? supplierId;
  String type = 'all';

  void reset() {
    range = ReportRange.today;
    customRange = null;
    productId = null;
    categoryId = null;
    customerId = null;
    supplierId = null;
    type = 'all';
  }
}
```

- [ ] **Step 2: Write `lib/src/app/controllers/report_controller.dart`**

```dart
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
  })  : _canManage = canManage,
        _customers = customers,
        _loadGenericReport = loadGenericReport,
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
```

> Behavior note: pre-split, `'all-transactions'` kind read `selectedCombinedReportType` and `'returns'` read `selectedReturnReportType`; both now map to `filterFor(kind).type`. `setCombinedType` mutates `report`, `setReturnType` mutates `returnReport` — same as before.

- [ ] **Step 3: Analyze**

Run: `flutter analyze lib/src/app/controllers/report_filter_state.dart lib/src/app/controllers/report_controller.dart` → `No issues found!`

- [ ] **Step 4: Wire into `AppController`**

1. Imports for both new files.
2. Build AFTER `featureRecords` (constructor body):
   ```dart
   reports = ReportController(
     _guard,
     _reportRepository,
     _transactionRepository,
     canManage: () => session.canManage,
     customers: () => customers.items,
     loadGenericReport: (kind, {search}) => featureRecords.loadGenericReport(
         kind, reports.reportQuery(kind: kind, search: search)),
     loadMoreGenericReport: (kind, {search}) => featureRecords.loadMoreGenericReport(
         kind, reports.reportQuery(kind: kind, search: search)),
   );
   reports.addListener(notifyListeners);
   ```
   Field: `late final ReportController reports;`. Remove+dispose in `dispose()`. `featureRecords`'s `onReportsInvalidated` stays `() {}` (the only report cache — the `/api/reports/*` feature-record entries — lives in `featureRecords`, and `invalidateReports()` already clears it there).
3. Delete from `app_controller.dart`: all `selectedReport*` + `selectedReturnReport*` fields (80-93), `salesReport` field (94), `_transactions` field (101), `transactions` getter (119), `loadSalesReport` (543-556), `reportRangeFor` (558-560), `customReportRangeFor` (562-568), the five `selectedReport*For` helpers (570-598), `setReportRange` (600-611), `setCustomReportRange` (613-628), `setReportProductFilter`/`setReportCategoryFilter`/`setReportCustomerFilter`/`setReportSupplierFilter` (630-691), `setCombinedReportType` (693-699), `setReturnReportType` (701-707), `exportSalesReport` (709-722), `reportQueryFor` (932-933), `_reportQuery` (935-968), `_exclusiveEnd` (970-973), `_quickDateRange` (975-990), `_matchingQuickRange` (992-1009).
4. Rewrite the generic-report wrappers to build the query via `reports.reportQuery`:
   ```dart
   Future<List<FeatureRecord>> loadGenericReport(String kind, {String? search}) =>
       featureRecords.loadGenericReport(kind, reports.reportQuery(kind: kind, search: search));
   Future<void> loadMoreGenericReport(String kind, {String? search}) =>
       featureRecords.loadMoreGenericReport(kind, reports.reportQuery(kind: kind, search: search));
   Future<List<int>?> exportGenericReport(String kind, {String? search}) =>
       featureRecords.exportGenericReport(kind, reports.reportQuery(kind: kind, search: search));
   ```
5. `checkout` (480-518): `_transactions = await _transactionRepository.fetchTransactions(...)` → `await reports.refetchTransactions(session.currentUser!);`; `_invalidateReports();` (already `featureRecords.invalidateReports();` from Task 7) unchanged; the `if (canManage) { salesReport = await _reportRepository.fetchSalesReport(...) }` block → `await reports.refetchSalesReportIfManager();`.
6. `refreshData` (520-541): `_transactions = await _transactionRepository.fetchTransactions(...)` → `await reports.refetchTransactions(session.currentUser!);`.
7. `login` (280-282): `loadSalesReport(selectedReportRange)` → `reports.loadSalesReport(reports.report.range)`; the two `loadGenericReport` calls unchanged (wrappers still exist).
8. `navigation` callback (from Task 3): `loadSalesReport(selectedReportRange)` → `reports.loadSalesReport(reports.report.range)`.
9. `logout`: report field resets → `reports.reset();`.
10. `selectedGenericReport` getter unchanged (delegates to `featureRecords`, Task 7).

- [ ] **Step 5: Migrate `reports_screen.dart` + `returns_screen.dart`**

```bash
grep -rn "AppScope.of(context)\.\(loadSalesReport\|salesReport\|transactions\|reportRangeFor\|customReportRangeFor\|selectedReport[A-Za-z]*For\|setReportRange\|setCustomReportRange\|setReport[A-Za-z]*Filter\|setCombinedReportType\|setReturnReportType\|exportSalesReport\|reportQueryFor\)" lib/
```
Map: `.loadSalesReport(` → `.reports.loadSalesReport(`; `.salesReport` → `.reports.salesReport`; `.transactions` → `.reports.transactions`; `.reportRangeFor(` → `.reports.reportRangeFor(`; `.customReportRangeFor(` → `.reports.customReportRangeFor(`; `.selectedReportProductIdFor(k)` → `.reports.filterFor(k).productId`; `Category`/`Customer`/`Supplier` likewise; `.selectedReportTypeFor(k)` → `.reports.filterFor(k).type`; `.setReportRange(` → `.reports.setRange(`; `.setCustomReportRange(` → `.reports.setCustomRange(`; `.setReportProductFilter(` → `.reports.setProductFilter(`; `.setReportCategoryFilter(` → `.reports.setCategoryFilter(`; `.setReportCustomerFilter(` → `.reports.setCustomerFilter(`; `.setReportSupplierFilter(` → `.reports.setSupplierFilter(`; `.setCombinedReportType(` → `.reports.setCombinedType(`; `.setReturnReportType(` → `.reports.setReturnType(`; `.exportSalesReport(` → `.reports.exportSalesReport(`; `.reportQueryFor(kind, search: s)` → `.reports.reportQuery(kind: kind, search: s)`.

- [ ] **Step 6: Migrate tests**

`test/app/app_controller_reports_test.dart`: `c.setReportRange(` → `c.reports.setRange(`; `c.reportRangeFor(` → `c.reports.reportRangeFor(`; `c.setCustomReportRange(` → `c.reports.setCustomRange(`; `c.reportQueryFor('all-transactions')` → `c.reports.reportQuery(kind: 'all-transactions')`; `c.setCombinedReportType(` → `c.reports.setCombinedType(`; `c.setReportCustomerFilter(` → `c.reports.setCustomerFilter(`; `c.selectedReportCustomerIdFor('all-transactions')` → `c.reports.filterFor('all-transactions').customerId`; `c.selectedReportSupplierIdFor('all-transactions')` → `c.reports.filterFor('all-transactions').supplierId`.
`test/app/app_controller_lifecycle_test.dart`: `c.setReportRange(ReportRange.week, kind: 'all-transactions')` → `c.reports.setRange(ReportRange.week, kind: 'all-transactions')`; `c.selectedReportRange` → `c.reports.report.range`. `c.selectedGenericReport` unchanged.

- [ ] **Step 7: Analyze + test**

Run: `flutter analyze` → `No issues found!`
Run: `flutter test` → all green.

- [ ] **Step 8: Commit**

```bash
git add lib/src/app/controllers/report_filter_state.dart lib/src/app/controllers/report_controller.dart lib/src/app/app_controller.dart lib/src/reports/screens/reports_screen.dart lib/src/returns/screens/returns_screen.dart test/app/
git commit -m "refactor: extract ReportController and collapse report/return filter duplication"
```

### 8b — `CartController`

**Files:**
- Create: `lib/src/app/controllers/cart_controller.dart`
- Modify: `lib/src/app/app_controller.dart`, `lib/src/pos/screens/pos_screen.dart` (6) + sweep, `test/widget_test.dart`, `test/app/app_controller_cart_test.dart`, `test/app/app_controller_lifecycle_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class CartController extends ChangeNotifier {
    CartController({
      required List<Product> Function() liveProducts,
      required Customer? Function() selectedCustomer,
      required List<FeatureRecord> Function() customerGroupDiscounts,
      required bool Function() isBusy,
    });
    List<CartLine> get lines;
    double get subtotal;
    double get discountAmount;
    double get grandTotal;
    double get cashChange;
    bool get canCheckout;
    String get paymentMethod;
    double get cashReceived;
    void addToCart(Product p);
    void decrementCart(Product p);
    void setCartQuantity(Product p, String value);
    void removeFromCart(Product p);
    void selectPaymentMethod(String value);
    void setCashReceived(String value);
    double discountRateForProduct(Product product, {Customer? customer});
    List<CartLine> takeLinesForCheckout();
    void clearAfterCheckout();
    void reset();
  }
  ```

- [ ] **Step 1: Write `lib/src/app/controllers/cart_controller.dart`**

```dart
import 'package:flutter/foundation.dart';

import '../../customers/models/customer.dart';
import '../../inventory/models/product.dart';
import '../../pos/models/cart_line.dart';
import '../../shared/models/feature_record.dart';

class CartController extends ChangeNotifier {
  CartController({
    required List<Product> Function() liveProducts,
    required Customer? Function() selectedCustomer,
    required List<FeatureRecord> Function() customerGroupDiscounts,
    required bool Function() isBusy,
  })  : _liveProducts = liveProducts,
        _selectedCustomer = selectedCustomer,
        _customerGroupDiscounts = customerGroupDiscounts,
        _isBusy = isBusy;

  final List<Product> Function() _liveProducts;
  final Customer? Function() _selectedCustomer;
  final List<FeatureRecord> Function() _customerGroupDiscounts;
  final bool Function() _isBusy;

  final Map<int, int> _cart = {};
  final Map<int, Product> _cartProducts = {};
  String _paymentMethod = 'cash';
  double _cashReceived = 0;

  String get paymentMethod => _paymentMethod;
  double get cashReceived => _cashReceived;

  List<CartLine> get lines {
    return _cart.entries
        .map((entry) {
          final product = _liveProducts()
                  .where((item) => item.id == entry.key)
                  .firstOrNull ??
              _cartProducts[entry.key];
          if (product == null) return null;
          return CartLine(product: product, quantity: entry.value);
        })
        .whereType<CartLine>()
        .toList(growable: false);
  }

  double get subtotal => lines.fold(0, (t, l) => t + l.subtotal);

  double get discountAmount {
    if (_selectedCustomer() == null) return 0;
    return lines.fold<double>(
      0,
      (t, l) => t + l.subtotal * discountRateForProduct(l.product),
    );
  }

  double get grandTotal => subtotal - discountAmount;

  double get cashChange =>
      _paymentMethod == 'cash' ? _cashReceived - grandTotal : 0;

  bool get canCheckout {
    if (lines.isEmpty || _isBusy()) return false;
    if (_paymentMethod != 'cash') return true;
    return _cashReceived >= grandTotal;
  }

  double discountRateForProduct(Product product, {Customer? customer}) {
    final effectiveCustomer = customer ?? _selectedCustomer();
    if (effectiveCustomer == null || product.categoryId == null) return 0;
    final match = _customerGroupDiscounts().where(
      (record) =>
          (record.values['customer_id'] as num?)?.toInt() == effectiveCustomer.id &&
          (record.values['category_id'] as num?)?.toInt() == product.categoryId,
    );
    if (match.isNotEmpty) {
      final rate = match.first.values['rate'];
      if (rate is num) return rate.toDouble();
      return double.tryParse(rate?.toString() ?? '') ?? 0;
    }
    return 0;
  }

  void addToCart(Product product) {
    final q = _cart[product.id] ?? 0;
    if (q >= product.stock) return;
    _cartProducts[product.id] = product;
    _cart[product.id] = q + 1;
    notifyListeners();
  }

  void decrementCart(Product product) {
    final q = _cart[product.id] ?? 0;
    if (q <= 1) {
      _cart.remove(product.id);
      _cartProducts.remove(product.id);
    } else {
      _cart[product.id] = q - 1;
    }
    notifyListeners();
  }

  void setCartQuantity(Product product, String value) {
    final quantity = int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (quantity <= 0) {
      _cart.remove(product.id);
      _cartProducts.remove(product.id);
    } else {
      _cart[product.id] = quantity.clamp(1, product.stock);
    }
    notifyListeners();
  }

  void removeFromCart(Product product) {
    _cart.remove(product.id);
    _cartProducts.remove(product.id);
    notifyListeners();
  }

  void selectPaymentMethod(String value) {
    _paymentMethod = value;
    _cashReceived = value == 'cash' ? _cashReceived : grandTotal;
    notifyListeners();
  }

  void setCashReceived(String value) {
    _cashReceived =
        double.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    notifyListeners();
  }

  List<CartLine> takeLinesForCheckout() => lines;

  void clearAfterCheckout() {
    _cart.clear();
    _cartProducts.clear();
    _cashReceived = 0;
    notifyListeners();
  }

  void reset() {
    _cart.clear();
    _cartProducts.clear();
    _paymentMethod = 'cash';
    _cashReceived = 0;
    notifyListeners();
  }
}
```

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/src/app/controllers/cart_controller.dart` → `No issues found!`

- [ ] **Step 3: Wire into `AppController`**

1. Import.
2. Build LAST in the constructor body (needs products, customers, featureRecords, guard):
   ```dart
   cart = CartController(
     liveProducts: () => products.items,
     selectedCustomer: () => customers.selected,
     customerGroupDiscounts: () => featureRecords.customerGroupDiscounts,
     isBusy: () => _guard.isBusy,
   );
   cart.addListener(notifyListeners);
   ```
   Field `late final CartController cart;`. Remove+dispose in `dispose()`.
3. Delete from `app_controller.dart`: `_cart` (108), `_cartProducts` (109), `selectedPaymentMethod` (96), `cashReceivedAmount` (97), `cartLines` (205-216), `subtotal` (218-219), `discountAmount` (221-228), `grandTotal` (230), `cashChange` (231-232), `canCheckout` (233-237), `discountRateForProduct` (242-257), `addToCart` (408-414), `decrementCart` (416-425), `setCartQuantity` (427-436), `removeFromCart` (438-442), `selectPaymentMethod` (340-344), `setCashReceived` (346-350).
4. `checkout` (480-518): `if (currentUser == null || cartLines.isEmpty) return null;` → `if (session.currentUser == null || cart.lines.isEmpty) return null;`; `final lines = cartLines;` → `final lines = cart.takeLinesForCheckout();`; `paymentMethod: selectedPaymentMethod` → `paymentMethod: cart.paymentMethod`; `cashReceived: selectedPaymentMethod == 'cash' ? cashReceivedAmount : grandTotal` → `cashReceived: cart.paymentMethod == 'cash' ? cart.cashReceived : cart.grandTotal`; `discountAmount: discountAmount` → `discountAmount: cart.discountAmount`; `_cart.clear(); _cartProducts.clear(); ... cashReceivedAmount = 0;` → `cart.clearAfterCheckout();`; `selectedCustomer = null;` → `customers.select(null);`.
5. `login` (270-273): `_cart.clear(); _cartProducts.clear(); selectedPaymentMethod = 'cash'; cashReceivedAmount = 0;` → `cart.reset();`.
6. `logout`: cart field resets → `cart.reset();`.

- [ ] **Step 4: Migrate `pos_screen.dart` + sweep**

```bash
grep -rn "AppScope.of(context)\.\(addToCart\|decrementCart\|setCartQuantity\|removeFromCart\|cartLines\|subtotal\|discountAmount\|grandTotal\|cashChange\|canCheckout\|selectedPaymentMethod\|cashReceivedAmount\|selectPaymentMethod\|setCashReceived\|discountRateForProduct\)" lib/
```
`.addToCart(` → `.cart.addToCart(`; `.decrementCart(` → `.cart.decrementCart(`; `.setCartQuantity(` → `.cart.setCartQuantity(`; `.removeFromCart(` → `.cart.removeFromCart(`; `.cartLines` → `.cart.lines`; `.subtotal` → `.cart.subtotal`; `.discountAmount` → `.cart.discountAmount`; `.grandTotal` → `.cart.grandTotal`; `.cashChange` → `.cart.cashChange`; `.canCheckout` → `.cart.canCheckout`; `.selectedPaymentMethod` → `.cart.paymentMethod`; `.cashReceivedAmount` → `.cart.cashReceived`; `.selectPaymentMethod(` → `.cart.selectPaymentMethod(`; `.setCashReceived(` → `.cart.setCashReceived(`; `.discountRateForProduct(` → `.cart.discountRateForProduct(`. `.checkout(` stays.

- [ ] **Step 5: Migrate tests**

`test/widget_test.dart`: `controller.addToCart(` → `controller.cart.addToCart(`; `controller.discountAmount` → `controller.cart.discountAmount`; `controller.grandTotal` → `controller.cart.grandTotal` (tests 3 and 4).
`test/app/app_controller_cart_test.dart`: prefix every cart member with `.cart` — `c.addToCart`→`c.cart.addToCart`, `c.cartLines`→`c.cart.lines`, `c.setCartQuantity`→`c.cart.setCartQuantity`, `c.discountAmount`→`c.cart.discountAmount`, `c.grandTotal`→`c.cart.grandTotal`, `c.setCashReceived`→`c.cart.setCashReceived`, `c.cashChange`→`c.cart.cashChange`, `c.selectPaymentMethod`→`c.cart.selectPaymentMethod`, `c.canCheckout`→`c.cart.canCheckout`, `c.decrementCart`→`c.cart.decrementCart`. Keep `c.customers.select` (Task 6), `c.products.items` (Task 5).
`test/app/app_controller_lifecycle_test.dart`: `c.addToCart(` → `c.cart.addToCart(`; `c.cartLines` → `c.cart.lines`.

- [ ] **Step 6: Analyze + test**

Run: `flutter analyze` → `No issues found!`
Run: `flutter test` → all green.

- [ ] **Step 7: Commit**

```bash
git add lib/src/app/controllers/cart_controller.dart lib/src/app/app_controller.dart lib/src/pos/screens/pos_screen.dart test/widget_test.dart test/app/
git commit -m "refactor: extract CartController from AppController"
```

### 8c — Final `AppController` shell + full sweep

- [ ] **Step 1: Read `lib/src/app/app_controller.dart` end to end**

It should now be: imports, `AppSection` enum, constructor (repos + `_guard` + 7 controllers + `addListener` + seed lists), `factory AppController.api`, `dispose`, delegating getters, and `login` / `loginAsRoleForTest` / `logout` / `refreshData` / `checkout`.

- [ ] **Step 2: Remove now-dead delegating getters**

For each delegating getter (`currentUser`, `isLoggedIn`, `canManage`, `canViewSection`, `selectedSection`, `isBusy`, `errorMessage`, `selectedGenericReport`), grep `lib/` + `test/` for external readers (`AppScope.of(context).<name>` or `controller.<name>`). Delete any with zero readers. Expected keepers: `isLoggedIn` (`pos_kasir_app.dart` — unless Task 4 migrated it to `.session.isLoggedIn`; if so, drop), `isBusy`/`errorMessage` (grep screens for a spinner/snackbar — keep only if read), `login`/`loginAsRoleForTest`/`logout`/`refreshData`/`checkout` (orchestration — keep).

- [ ] **Step 3: Verify constructor ordering**

`late final` controllers initialize on first touch; the `addListener` calls in the constructor body force that order: build `products`, `customers`, `featureRecords`, `session`, `navigation`, `reports`, `cart` (each followed by `addListener`). If a `LateInitializationError` or a dependency cycle shows up in `flutter test`, convert the involved `late final` fields to plain `final` assigned explicitly in the constructor body in that order.

- [ ] **Step 4: Full analyze + test + format**

Run: `flutter analyze` → `No issues found!`
Run: `flutter test` → all green.
Run: `dart format lib/src/app/ test/app/` and stage the result.

- [ ] **Step 5: Manual smoke**

```bash
flutter run -d chrome
```
Log in blank (cashier), then `manajer`, then `admin`. For each: POS add-to-cart + cash checkout shows "Transaksi Berhasil"; Inventory filter + "muat lebih"; a Master-data table create + delete; (manager/admin) Reports range switch + export; Returns report filter. No console exceptions.

- [ ] **Step 6: Commit**

```bash
git add lib/src/app/ test/
git commit -m "refactor: reduce AppController to construction + orchestration"
```

- [ ] **Step 7: Refresh the graph (optional, verifies the win)**

```bash
graphify . --update
```
Expected: community 0 cohesion rises; `app_controller.dart` node degree drops sharply.

---

## Self-Review

**Spec coverage:**
- Seven controllers + `AsyncGuard` + `ReportFilterState` → Tasks 2–8. ✓
- Report/return duplication collapse → Task 8a (`ReportFilterState` ×2). ✓
- Busy/error consolidation → Task 2. ✓
- Behavior preservation → characterization suite (Task 1), green-gate every task. ✓
- Namespaced access on `AppScope` → every task's screen-migration step. ✓
- One `InheritedNotifier`, re-broadcast in one hop → Task 2 `dispose` + `addListener` in every task. ✓
- Dependency direction / injection → Interfaces blocks (callbacks in Tasks 3/4/7, sibling refs in 8). ✓
- Orchestration methods stay on `AppController` → Task 8c. ✓
- Sequencing 1–8 → task order matches spec. ✓
- `test/widget_test.dart` breakage from direct member access → Global Constraints + migrated in Tasks 3, 5, 6, 8b. ✓

**Placeholder scan:** Task 1 Step 7 leaves two `Product(...)` constructors and one inline fake to be filled from the real model — flagged explicitly with the exact behavior each must exhibit (the stale-response guard it exercises). Task 5 Step 3 and Task 8c Step 3 hold "verify X else do Y" branches — both branches are specified; the check is a real fact about `MockProductRepository` / `late final` ordering the implementer must confirm against source. No bare `TODO`/`TBD`/"handle edge cases".

**Type consistency:** getter/method names are stable across tasks — `ProductController`: `items`/`setSearch`/`save`/`remove`/`reload`/`canLoadMore`; `CustomerController`: `items`/`select`/`search`/`save`/`remove`/`reload`/`canLoadMore`/`selected`; `FeatureRecordController`: `records`/`load`/`loadMore`/`save`/`remove`/`canLoadMore`/`invalidateReports`/`customerGroupDiscounts`/`selectedGenericReport`; `ReportController`: `filterFor`/`reportRangeFor`/`customReportRangeFor`/`setRange`/`setCustomRange`/`setProductFilter`/`setCategoryFilter`/`setCustomerFilter`/`setSupplierFilter`/`setCombinedType`/`setReturnType`/`reportQuery`/`exportSalesReport`/`loadSalesReport`/`refetchTransactions`/`refetchSalesReportIfManager`/`salesReport`/`transactions`; `CartController`: `lines`/`subtotal`/`discountAmount`/`grandTotal`/`cashChange`/`canCheckout`/`paymentMethod`/`cashReceived`/`addToCart`/`decrementCart`/`setCartQuantity`/`removeFromCart`/`selectPaymentMethod`/`setCashReceived`/`discountRateForProduct`/`takeLinesForCheckout`/`clearAfterCheckout`/`reset`; `AsyncGuard`: `run`/`reportError`/`clearError`/`isBusy`/`errorMessage`. `AppController` fields: `session`/`navigation`/`products`/`customers`/`featureRecords`/`reports`/`cart` throughout.
