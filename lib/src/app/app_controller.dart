import 'package:flutter/material.dart';

import '../auth/models/app_user.dart';
import '../auth/repositories/auth_repository.dart';
import '../customers/models/customer.dart';
import '../customers/repositories/customer_repository.dart';
import '../inventory/models/product.dart';
import '../inventory/repositories/product_repository.dart';
import '../pos/models/cart_line.dart';
import '../reports/models/sale_transaction.dart';
import '../reports/repositories/report_repository.dart';
import '../reports/repositories/transaction_repository.dart';
import '../shared/api/api_client.dart';
import '../shared/data/mock_data_store.dart';
import '../shared/models/feature_record.dart';
import '../shared/repositories/feature_repository.dart';
import 'async_guard.dart';
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
  }

  late final SessionController session = SessionController(
    rolePermissionRecords: () => featureRecords.records('/api/role-permissions'),
  );

  late final NavigationController navigation = NavigationController(
    canView: canViewSection,
    onEnterSection: (section) {
      if (section == AppSection.reports && canManage) {
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

  late final ProductController products;
  late final FeatureRecordController featureRecords;
  late final CustomerController customers;
  late final ReportController reports;
  final AsyncGuard _guard = AsyncGuard();
  String get selectedGenericReport => featureRecords.selectedGenericReport;
  String selectedPaymentMethod = 'cash';
  double cashReceivedAmount = 0;

  final Map<int, int> _cart = {};
  final Map<int, Product> _cartProducts = {};
  Future<void>? _refreshDataFuture;

  bool get isBusy => _guard.isBusy;
  String? get errorMessage => _guard.errorMessage;

  AppUser? get currentUser => session.currentUser;
  bool get isLoggedIn => session.isLoggedIn;
  bool get canManage => session.canManage;
  bool canViewSection(AppSection s) => session.canViewSection(s);

  AppSection get selectedSection => navigation.selectedSection;

  List<CartLine> get cartLines {
    return _cart.entries
        .map((entry) {
          final product =
              products.items.where((item) => item.id == entry.key).firstOrNull ??
              _cartProducts[entry.key];
          if (product == null) return null;
          return CartLine(product: product, quantity: entry.value);
        })
        .whereType<CartLine>()
        .toList(growable: false);
  }

  double get subtotal =>
      cartLines.fold(0, (total, line) => total + line.subtotal);

  double get discountAmount {
    if (customers.selected == null) return 0;
    return cartLines.fold<double>(
      0,
      (total, line) =>
          total + line.subtotal * discountRateForProduct(line.product),
    );
  }

  double get grandTotal => subtotal - discountAmount;
  double get cashChange =>
      selectedPaymentMethod == 'cash' ? cashReceivedAmount - grandTotal : 0;
  bool get canCheckout {
    if (cartLines.isEmpty || isBusy) return false;
    if (selectedPaymentMethod != 'cash') return true;
    return cashReceivedAmount >= grandTotal;
  }

  double discountRateForProduct(Product product, {Customer? customer}) {
    final effectiveCustomer = customer ?? customers.selected;
    if (effectiveCustomer == null || product.categoryId == null) return 0;
    final match = featureRecords.customerGroupDiscounts.where(
      (record) =>
          (record.values['customer_id'] as num?)?.toInt() ==
              effectiveCustomer.id &&
          (record.values['category_id'] as num?)?.toInt() == product.categoryId,
    );
    if (match.isNotEmpty) {
      final rate = match.first.values['rate'];
      if (rate is num) return rate.toDouble();
      return double.tryParse(rate?.toString() ?? '') ?? 0;
    }
    return 0;
  }

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
      _cart.clear();
      _cartProducts.clear();
      selectedPaymentMethod = 'cash';
      cashReceivedAmount = 0;
      await refreshData();
      await featureRecords.load('/api/product-categories');
      await featureRecords.load('/api/suppliers');
      await featureRecords.load('/api/customer-group-discounts');
      await featureRecords.load('/api/role-permissions');
      if (canManage) {
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
    _cart.clear();
    _cartProducts.clear();
    selectedPaymentMethod = 'cash';
    cashReceivedAmount = 0;
    notifyListeners();
  }

  void selectPaymentMethod(String value) {
    selectedPaymentMethod = value;
    cashReceivedAmount = value == 'cash' ? cashReceivedAmount : grandTotal;
    notifyListeners();
  }

  void setCashReceived(String value) {
    cashReceivedAmount =
        double.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    notifyListeners();
  }

  void addToCart(Product product) {
    final currentQuantity = _cart[product.id] ?? 0;
    if (currentQuantity >= product.stock) return;
    _cartProducts[product.id] = product;
    _cart[product.id] = currentQuantity + 1;
    notifyListeners();
  }

  void decrementCart(Product product) {
    final currentQuantity = _cart[product.id] ?? 0;
    if (currentQuantity <= 1) {
      _cart.remove(product.id);
      _cartProducts.remove(product.id);
    } else {
      _cart[product.id] = currentQuantity - 1;
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

  Future<SaleTransaction?> checkout() async {
    if (currentUser == null || cartLines.isEmpty) return null;
    SaleTransaction? transaction;
    final lines = cartLines;
    await _runBusy(() async {
      transaction = await _transactionRepository.createTransaction(
        user: currentUser!,
        customer: customers.selected,
        lines: lines,
        paymentMethod: selectedPaymentMethod,
        cashReceived: selectedPaymentMethod == 'cash'
            ? cashReceivedAmount
            : grandTotal,
        discountAmount: discountAmount,
      );
      await products.reload();
      await customers.reload();
      await reports.refetchTransactions(session.currentUser!);
      featureRecords.invalidateReports();
      _cart.clear();
      _cartProducts.clear();
      customers.select(null);
      cashReceivedAmount = 0;
      await reports.refetchSalesReportIfManager();
    });
    return transaction;
  }

  Future<void> refreshData() async {
    if (currentUser == null) return;
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

  Future<List<FeatureRecord>> loadGenericReport(String kind, {String? search}) =>
      featureRecords.loadGenericReport(
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
    super.dispose();
  }
}
