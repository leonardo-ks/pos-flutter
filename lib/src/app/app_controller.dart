import 'package:flutter/material.dart';

import '../auth/models/app_user.dart';
import '../auth/repositories/auth_repository.dart';
import '../customers/repositories/customer_repository.dart';
import '../inventory/repositories/product_repository.dart';
import '../reports/models/sale_transaction.dart';
import '../reports/repositories/report_repository.dart';
import '../reports/repositories/transaction_repository.dart';
import '../shared/api/api_client.dart';
import '../shared/data/mock_data_store.dart';
import '../shared/models/feature_record.dart';
import '../shared/repositories/feature_repository.dart';
import 'async_guard.dart';
import 'controllers/cart_controller.dart';
import 'controllers/customer_controller.dart';
import 'controllers/feature_record_controller.dart';
import 'controllers/navigation_controller.dart';
import 'controllers/product_controller.dart';
import 'controllers/report_controller.dart';
import 'controllers/session_controller.dart';

enum AppSection { pos, purchases, returns, reports, master, users }

class AppController extends ChangeNotifier {
  AppController({
    AuthRepository? authRepository,
    ProductRepository? productRepository,
    CustomerRepository? customerRepository,
    TransactionRepository? transactionRepository,
    ReportRepository? reportRepository,
    FeatureRepository? featureRepository,
    MockDataStore? store,
  }) {
    final dataStore = store ?? MockDataStore.seeded();
    _authRepository = authRepository ?? MockAuthRepository(session.demoUsers);
    _productRepository = productRepository ?? MockProductRepository(dataStore);
    _customerRepository =
        customerRepository ?? MockCustomerRepository(dataStore);
    _transactionRepository =
        transactionRepository ?? MockTransactionRepository(dataStore);
    _reportRepository = reportRepository ?? MockReportRepository(dataStore);
    _featureRepository = featureRepository ?? MockFeatureRepository();
    products = ProductController(
      _guard,
      _productRepository,
      initialItems: dataStore.products,
    );
    featureRecords = FeatureRecordController(
      _guard,
      _featureRepository,
      products: products,
      onReportsInvalidated: () {},
    );
    customers = CustomerController(
      _guard,
      _customerRepository,
      initialItems: dataStore.customers,
    );
    reports = ReportController(
      _guard,
      _reportRepository,
      _transactionRepository,
      canManage: () => session.canManage,
      customers: () => customers.items,
      loadGenericReport: (kind, {search}) => featureRecords.loadGenericReport(
        kind,
        reports.reportQuery(kind: kind, search: search),
      ),
      loadMoreGenericReport: (kind, {search}) =>
          featureRecords.loadMoreGenericReport(
            kind,
            reports.reportQuery(kind: kind, search: search),
          ),
    );
    _guard.addListener(notifyListeners);
    products.addListener(notifyListeners);
    featureRecords.addListener(notifyListeners);
    customers.addListener(notifyListeners);
    reports.addListener(notifyListeners);
    // session must init before navigation: navigation's canView delegates to it.
    session.addListener(notifyListeners);
    navigation.addListener(notifyListeners);
    cart = CartController(
      liveProducts: () => products.items,
      selectedCustomer: () => customers.selected,
      customerGroupDiscounts: () => featureRecords.customerGroupDiscounts,
      isBusy: () => _guard.isBusy,
    );
    cart.addListener(notifyListeners);
  }

  late final SessionController session = SessionController(
    rolePermissionRecords: () =>
        featureRecords.records('/api/role-permissions'),
  );

  late final NavigationController navigation = NavigationController(
    canView: session.canViewSection,
    onEnterSection: (section) {
      if (section == AppSection.reports && session.canManage) {
        reports.loadSalesReport(reports.report.range);
        loadGenericReport('all-transactions');
        loadGenericReport('returns');
      }
    },
  );

  factory AppController.api({ApiClient? apiClient}) {
    final client = apiClient ?? ApiClient();
    return AppController(
      authRepository: ApiAuthRepository(client),
      productRepository: ApiProductRepository(client),
      customerRepository: ApiCustomerRepository(client),
      transactionRepository: ApiTransactionRepository(client),
      reportRepository: ApiReportRepository(client),
      featureRepository: ApiFeatureRepository(client),
    );
  }

  late final AuthRepository _authRepository;
  late final ProductRepository _productRepository;
  late final CustomerRepository _customerRepository;
  late final TransactionRepository _transactionRepository;
  late final ReportRepository _reportRepository;
  late final FeatureRepository _featureRepository;

  // These 7 sub-controllers are `late final`; their init order is not fixed and
  // not relied upon (the no-arg constructor builds `session` first via
  // MockAuthRepository(session.demoUsers); AppController.api builds it after
  // `reports`). No sub-controller calls a sibling during its own construction --
  // every cross-controller reference above is a closure/tear-off evaluated later,
  // post-construction. The one ordering constraint: `navigation`'s injected
  // `canView` needs `session` to exist, which the constructor body's addListener
  // sequence (session before navigation) guarantees. `_guard` is a plain `final`.
  late final ProductController products;
  late final FeatureRecordController featureRecords;
  late final CustomerController customers;
  late final ReportController reports;
  late final CartController cart;
  final AsyncGuard _guard = AsyncGuard();
  String get selectedGenericReport => featureRecords.selectedGenericReport;

  Future<void>? _refreshDataFuture;

  bool get isBusy => _guard.isBusy;
  String? get errorMessage => _guard.errorMessage;

  AppSection get selectedSection => navigation.selectedSection;

  Future<void> login({
    required String username,
    required String password,
  }) async {
    await _runBusy(() async {
      await session.authenticate(
        _authRepository,
        username: username,
        password: password,
      );
      navigation.reset();
      customers.select(null);
      cart.reset();
      await refreshData();
      await featureRecords.load('/api/product-categories');
      await featureRecords.load('/api/suppliers');
      await featureRecords.load('/api/customer-group-discounts');
      await featureRecords.load('/api/role-permissions');
      if (session.canManage) {
        await reports.loadSalesReport(reports.report.range);
        await loadGenericReport('all-transactions');
        await loadGenericReport('returns');
      }
    });
  }

  Future<void> loginAsRoleForTest(UserRole role) {
    return login(
      username: switch (role) {
        UserRole.manager => 'manajer',
        UserRole.administrator => 'admin',
        UserRole.cashier => 'kasir',
      },
      password: 'password1234',
    );
  }

  void logout() {
    session.reset();
    navigation.reset();
    customers.reset();
    products.reset();
    _guard.clearError();
    reports.reset();
    featureRecords.reset();
    _refreshDataFuture = null;
    cart.reset();
    notifyListeners();
  }

  Future<SaleTransaction?> checkout() async {
    if (session.currentUser == null || cart.lines.isEmpty) return null;
    SaleTransaction? transaction;
    final lines = cart.takeLinesForCheckout();
    await _runBusy(() async {
      transaction = await _transactionRepository.createTransaction(
        user: session.currentUser!,
        customer: customers.selected,
        lines: lines,
        paymentMethod: cart.paymentMethod,
        cashReceived: cart.paymentMethod == 'cash'
            ? cart.cashReceived
            : cart.grandTotal,
        discountAmount: cart.discountAmount,
      );
      await products.reload();
      await customers.reload();
      await reports.refetchTransactions(session.currentUser!);
      featureRecords.invalidateReports();
      cart.clearAfterCheckout();
      customers.select(null);
      await reports.refetchSalesReportIfManager();
    });
    return transaction;
  }

  Future<void> refreshData() async {
    if (session.currentUser == null) return;
    final currentRefresh = _refreshDataFuture;
    if (currentRefresh != null) {
      await currentRefresh;
      return;
    }
    final refresh = () async {
      await products.reload();
      await customers.reload();
      await reports.refetchTransactions(session.currentUser!);
    }();
    _refreshDataFuture = refresh;
    try {
      await refresh;
    } finally {
      _refreshDataFuture = null;
    }
  }

  Future<List<FeatureRecord>> loadGenericReport(
    String kind, {
    String? search,
  }) => featureRecords.loadGenericReport(
    kind,
    reports.reportQuery(kind: kind, search: search),
  );

  Future<void> loadMoreGenericReport(String kind, {String? search}) =>
      featureRecords.loadMoreGenericReport(
        kind,
        reports.reportQuery(kind: kind, search: search),
      );

  Future<List<int>?> exportGenericReport(String kind, {String? search}) =>
      featureRecords.exportGenericReport(
        kind,
        reports.reportQuery(kind: kind, search: search),
      );

  Future<void> _runBusy(Future<void> Function() action) => _guard.run(action);

  @override
  void dispose() {
    _guard.removeListener(notifyListeners);
    _guard.dispose();
    products.removeListener(notifyListeners);
    products.dispose();
    featureRecords.removeListener(notifyListeners);
    featureRecords.dispose();
    customers.removeListener(notifyListeners);
    customers.dispose();
    reports.removeListener(notifyListeners);
    reports.dispose();
    session.removeListener(notifyListeners);
    session.dispose();
    navigation.removeListener(notifyListeners);
    navigation.dispose();
    cart.removeListener(notifyListeners);
    cart.dispose();
    super.dispose();
  }
}
