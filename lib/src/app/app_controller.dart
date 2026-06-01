import 'package:flutter/material.dart';

import '../auth/models/app_user.dart';
import '../auth/repositories/auth_repository.dart';
import '../customers/models/customer.dart';
import '../customers/repositories/customer_repository.dart';
import '../inventory/models/product.dart';
import '../inventory/repositories/product_repository.dart';
import '../pos/models/cart_line.dart';
import '../reports/models/sale_transaction.dart';
import '../reports/models/sales_report.dart';
import '../reports/repositories/report_repository.dart';
import '../reports/repositories/transaction_repository.dart';
import '../shared/api/api_client.dart';
import '../shared/data/mock_data_store.dart';
import '../shared/models/feature_record.dart';
import '../shared/repositories/feature_repository.dart';

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
    _authRepository = authRepository ?? MockAuthRepository(demoUsers);
    _productRepository = productRepository ?? MockProductRepository(dataStore);
    _customerRepository =
        customerRepository ?? MockCustomerRepository(dataStore);
    _transactionRepository =
        transactionRepository ?? MockTransactionRepository(dataStore);
    _reportRepository = reportRepository ?? MockReportRepository(dataStore);
    _featureRepository = featureRepository ?? MockFeatureRepository();
    _products = List.unmodifiable(dataStore.products);
    _customers = List.unmodifiable(dataStore.customers);
    _transactions = List.unmodifiable(dataStore.transactions);
  }

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

  final List<AppUser> demoUsers = const [
    AppUser(id: 1, name: 'Dewi Kasir', role: UserRole.cashier),
    AppUser(id: 2, name: 'Bima Manajer', role: UserRole.manager),
    AppUser(id: 3, name: 'Ari Administrator', role: UserRole.administrator),
  ];

  AppUser? currentUser;
  AppSection selectedSection = AppSection.pos;
  Customer? selectedCustomer;
  String productSearch = '';
  int? selectedProductCategoryFilterId;
  int? selectedProductLocationFilterId;
  String selectedProductStockFilter = 'all';
  bool isBusy = false;
  String? errorMessage;
  int _busyDepth = 0;
  ReportRange selectedReportRange = ReportRange.today;
  DateTimeRange? customReportRange;
  int? selectedReportProductId;
  int? selectedReportCategoryId;
  int? selectedReportCustomerId;
  int? selectedReportSupplierId;
  ReportRange selectedReturnReportRange = ReportRange.today;
  DateTimeRange? customReturnReportRange;
  int? selectedReturnReportProductId;
  int? selectedReturnReportCategoryId;
  int? selectedReturnReportCustomerId;
  int? selectedReturnReportSupplierId;
  String selectedCombinedReportType = 'all';
  String selectedReturnReportType = 'all';
  SalesReport salesReport = SalesReport.empty();
  String selectedGenericReport = 'purchases';
  String selectedPaymentMethod = 'cash';
  double cashReceivedAmount = 0;

  List<Product> _products = [];
  List<Customer> _customers = [];
  List<SaleTransaction> _transactions = [];
  final Map<String, List<FeatureRecord>> _featureRecords = {};
  final Map<String, String> _featureQueryKeys = {};
  final Map<String, String?> _featureNextCursors = {};
  final Map<String, Future<void>> _featureLoadFutures = {};
  String? _productNextCursor;
  String? _customerNextCursor;
  final Map<int, int> _cart = {};
  final Map<int, Product> _cartProducts = {};
  Future<void>? _refreshDataFuture;

  bool get isLoggedIn => currentUser != null;
  bool get isManager => currentUser?.role == UserRole.manager;
  bool get isAdministrator => currentUser?.role == UserRole.administrator;
  bool get canManage => isManager || isAdministrator;

  List<Product> get products => List<Product>.from(_products);
  List<Customer> get customers => List.unmodifiable(_customers);
  List<SaleTransaction> get transactions => List.unmodifiable(_transactions);

  List<AppSection> get availableSections {
    final sections = [
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
      AppSection.master =>
        canViewMenu('inventory') ||
            canViewMenu('customers') ||
            canViewMenu('suppliers'),
      AppSection.users =>
        canViewMenu('users') ||
            canViewMenu('roles') ||
            canViewMenu('authorization') ||
            isAdministrator,
    };
  }

  bool canViewMenu(String section) {
    if (isAdministrator && _featureRecords['/api/role-permissions'] == null) {
      return true;
    }
    final permission = _rolePermission(section);
    if (permission != null) return permission.values['can_view'] == true;
    return switch (currentUser?.role) {
      UserRole.administrator => true,
      UserRole.manager => !{
        'users',
        'roles',
        'authorization',
      }.contains(section),
      UserRole.cashier => {'pos', 'inventory', 'customers'}.contains(section),
      null => false,
    };
  }

  bool canCreateMenu(String section) => _canCrud(section, 'can_create');
  bool canUpdateMenu(String section) => _canCrud(section, 'can_update');
  bool canDeleteMenu(String section) => _canCrud(section, 'can_delete');

  bool _canCrud(String section, String key) {
    if (isAdministrator && _featureRecords['/api/role-permissions'] == null) {
      return true;
    }
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
    final records = _featureRecords['/api/role-permissions'];
    if (records == null) return null;
    return records
        .where(
          (record) =>
              record.values['role'] == role &&
              record.values['section'] == section,
        )
        .firstOrNull;
  }

  List<Product> get filteredProducts {
    return products;
  }

  List<CartLine> get cartLines {
    return _cart.entries
        .map((entry) {
          final product =
              _products.where((item) => item.id == entry.key).firstOrNull ??
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
    if (selectedCustomer == null) return 0;
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

  List<FeatureRecord> get customerGroupDiscounts =>
      featureRecords('/api/customer-group-discounts');

  double discountRateForProduct(Product product, {Customer? customer}) {
    final effectiveCustomer = customer ?? selectedCustomer;
    if (effectiveCustomer == null || product.categoryId == null) return 0;
    final match = customerGroupDiscounts.where(
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
      currentUser = await _authRepository.login(
        username: username,
        password: password,
      );
      selectedSection = AppSection.pos;
      selectedCustomer = null;
      _cart.clear();
      _cartProducts.clear();
      selectedPaymentMethod = 'cash';
      cashReceivedAmount = 0;
      await refreshData();
      await loadFeatureRecords('/api/product-categories');
      await loadFeatureRecords('/api/suppliers');
      await loadFeatureRecords('/api/customer-group-discounts');
      await loadFeatureRecords('/api/role-permissions');
      if (canManage) {
        await loadSalesReport(selectedReportRange);
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
    currentUser = null;
    selectedSection = AppSection.pos;
    selectedCustomer = null;
    productSearch = '';
    selectedProductCategoryFilterId = null;
    selectedProductLocationFilterId = null;
    selectedProductStockFilter = 'all';
    errorMessage = null;
    selectedReportRange = ReportRange.today;
    customReportRange = null;
    selectedReportProductId = null;
    selectedReportCategoryId = null;
    selectedReportCustomerId = null;
    selectedReportSupplierId = null;
    selectedReturnReportRange = ReportRange.today;
    customReturnReportRange = null;
    selectedReturnReportProductId = null;
    selectedReturnReportCategoryId = null;
    selectedReturnReportCustomerId = null;
    selectedReturnReportSupplierId = null;
    selectedCombinedReportType = 'all';
    selectedReturnReportType = 'all';
    selectedGenericReport = 'purchases';
    salesReport = SalesReport.empty();
    _products = const [];
    _customers = const [];
    _transactions = const [];
    _featureRecords.clear();
    _featureQueryKeys.clear();
    _featureNextCursors.clear();
    _featureLoadFutures.clear();
    _productNextCursor = null;
    _customerNextCursor = null;
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

  void selectSection(AppSection section) {
    if (!availableSections.contains(section)) return;
    if (selectedSection == section) return;
    selectedSection = section;
    notifyListeners();
    if (section == AppSection.reports && canManage) {
      loadSalesReport(selectedReportRange);
      loadGenericReport('all-transactions');
      loadGenericReport('returns');
    }
  }

  void setProductSearch(String value) {
    productSearch = value;
    _productNextCursor = null;
    notifyListeners();
    _productRepository
        .fetchProductPage(
          query: value,
          categoryId: selectedProductCategoryFilterId,
          locationId: selectedProductLocationFilterId,
          stockFilter: selectedProductStockFilter == 'all'
              ? null
              : selectedProductStockFilter,
        )
        .then((page) {
          if (productSearch != value) return;
          _products = page.rows;
          _productNextCursor = page.nextCursor;
          notifyListeners();
        })
        .catchError((Object error) {
          errorMessage = error.toString();
          notifyListeners();
        });
  }

  void selectCustomer(Customer? customer) {
    selectedCustomer = customer;
    notifyListeners();
  }

  Future<void> searchCustomers(String value) async {
    try {
      _customerNextCursor = null;
      notifyListeners();
      final page = await _customerRepository.fetchCustomerPage(query: value);
      _customers = page.rows;
      _customerNextCursor = page.nextCursor;
      notifyListeners();
    } catch (error) {
      errorMessage = error.toString();
      notifyListeners();
    }
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

  Future<Product?> saveProduct(Product product) async {
    Product? saved;
    await _runBusy(() async {
      saved = await _productRepository.upsertProduct(product);
      await _loadProductPage();
    });
    return saved;
  }

  Future<void> deleteProduct(Product product) async {
    await _runBusy(() async {
      await _productRepository.deleteProduct(product.id);
      await _loadProductPage();
    });
  }

  Future<Customer?> saveCustomer(Customer customer) async {
    Customer? saved;
    await _runBusy(() async {
      saved = await _customerRepository.upsertCustomer(customer);
      await _loadCustomerPage();
      if (selectedCustomer?.id == saved?.id) {
        selectedCustomer = saved;
      }
    });
    return saved;
  }

  Future<void> deleteCustomer(Customer customer) async {
    await _runBusy(() async {
      await _customerRepository.deleteCustomer(customer.id);
      await _loadCustomerPage();
      if (selectedCustomer?.id == customer.id) selectedCustomer = null;
    });
  }

  Future<SaleTransaction?> checkout() async {
    if (currentUser == null || cartLines.isEmpty) return null;
    SaleTransaction? transaction;
    final lines = cartLines;
    await _runBusy(() async {
      transaction = await _transactionRepository.createTransaction(
        user: currentUser!,
        customer: selectedCustomer,
        lines: lines,
        paymentMethod: selectedPaymentMethod,
        cashReceived: selectedPaymentMethod == 'cash'
            ? cashReceivedAmount
            : grandTotal,
        discountAmount: discountAmount,
      );
      await _loadProductPage();
      await _loadCustomerPage();
      _transactions = await _transactionRepository.fetchTransactions(
        user: currentUser!,
        customers: _customers,
      );
      _invalidateReports();
      _cart.clear();
      _cartProducts.clear();
      selectedCustomer = null;
      cashReceivedAmount = 0;
      if (canManage) {
        salesReport = await _reportRepository.fetchSalesReport(
          selectedReportRange,
          from: customReportRange?.start,
          to: _exclusiveEnd(customReportRange?.end),
          productId: selectedReportProductId,
          categoryId: selectedReportCategoryId,
          customerId: selectedReportCustomerId,
        );
      }
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
      await _loadProductPage();
      await _loadCustomerPage();
      _transactions = await _transactionRepository.fetchTransactions(
        user: currentUser!,
        customers: _customers,
      );
    }();
    _refreshDataFuture = refresh;
    try {
      await refresh;
    } finally {
      _refreshDataFuture = null;
    }
  }

  Future<void> loadSalesReport(ReportRange range) async {
    if (!canManage) return;
    selectedReportRange = range;
    await _runBusy(() async {
      salesReport = await _reportRepository.fetchSalesReport(
        range,
        from: customReportRange?.start,
        to: _exclusiveEnd(customReportRange?.end),
        productId: selectedReportProductId,
        categoryId: selectedReportCategoryId,
        customerId: selectedReportCustomerId,
      );
    });
  }

  ReportRange reportRangeFor(String kind) {
    return kind == 'returns' ? selectedReturnReportRange : selectedReportRange;
  }

  DateTimeRange? customReportRangeFor(String kind) {
    final range = reportRangeFor(kind);
    if (range == ReportRange.custom) {
      return kind == 'returns' ? customReturnReportRange : customReportRange;
    }
    return _quickDateRange(range);
  }

  int? selectedReportProductIdFor(String kind) {
    return kind == 'returns'
        ? selectedReturnReportProductId
        : selectedReportProductId;
  }

  int? selectedReportCategoryIdFor(String kind) {
    return kind == 'returns'
        ? selectedReturnReportCategoryId
        : selectedReportCategoryId;
  }

  int? selectedReportCustomerIdFor(String kind) {
    return kind == 'returns'
        ? selectedReturnReportCustomerId
        : selectedReportCustomerId;
  }

  int? selectedReportSupplierIdFor(String kind) {
    return kind == 'returns'
        ? selectedReturnReportSupplierId
        : selectedReportSupplierId;
  }

  String selectedReportTypeFor(String kind) {
    return kind == 'returns'
        ? selectedReturnReportType
        : selectedCombinedReportType;
  }

  Future<void> setReportRange(ReportRange range, {required String kind}) async {
    if (kind == 'returns') {
      selectedReturnReportRange = range;
      if (range != ReportRange.custom) customReturnReportRange = null;
      await loadGenericReport('returns');
      return;
    }
    selectedReportRange = range;
    if (range != ReportRange.custom) customReportRange = null;
    await loadSalesReport(range);
    await loadGenericReport('all-transactions');
  }

  Future<void> setCustomReportRange(
    DateTimeRange range, {
    String kind = 'all-transactions',
  }) async {
    final matchedRange = _matchingQuickRange(range);
    if (kind == 'returns') {
      selectedReturnReportRange = matchedRange ?? ReportRange.custom;
      customReturnReportRange = matchedRange == null ? range : null;
      await loadGenericReport('returns');
      return;
    }
    selectedReportRange = matchedRange ?? ReportRange.custom;
    customReportRange = matchedRange == null ? range : null;
    await loadSalesReport(selectedReportRange);
    await loadGenericReport('all-transactions');
  }

  Future<void> setReportProductFilter(
    int? productId, {
    String kind = 'all-transactions',
  }) async {
    if (kind == 'returns') {
      selectedReturnReportProductId = productId;
      notifyListeners();
      await loadGenericReport('returns');
      return;
    }
    selectedReportProductId = productId;
    notifyListeners();
    await loadSalesReport(selectedReportRange);
    await loadGenericReport('all-transactions');
  }

  Future<void> setReportCategoryFilter(
    int? categoryId, {
    String kind = 'all-transactions',
  }) async {
    if (kind == 'returns') {
      selectedReturnReportCategoryId = categoryId;
      notifyListeners();
      await loadGenericReport('returns');
      return;
    }
    selectedReportCategoryId = categoryId;
    notifyListeners();
    await loadSalesReport(selectedReportRange);
    await loadGenericReport('all-transactions');
  }

  Future<void> setReportCustomerFilter(
    int? customerId, {
    String kind = 'all-transactions',
  }) async {
    if (kind == 'returns') {
      selectedReturnReportCustomerId = customerId;
      notifyListeners();
      await loadGenericReport('returns');
      return;
    }
    selectedReportCustomerId = customerId;
    notifyListeners();
    await loadSalesReport(selectedReportRange);
    await loadGenericReport('all-transactions');
  }

  Future<void> setReportSupplierFilter(
    int? supplierId, {
    String kind = 'all-transactions',
  }) async {
    if (kind == 'returns') {
      selectedReturnReportSupplierId = supplierId;
      notifyListeners();
      await loadGenericReport('returns');
      return;
    }
    selectedReportSupplierId = supplierId;
    notifyListeners();
    await loadGenericReport('all-transactions');
  }

  Future<void> setCombinedReportType(String type) async {
    selectedCombinedReportType = type;
    selectedReportCustomerId = null;
    selectedReportSupplierId = null;
    notifyListeners();
    await loadGenericReport('all-transactions');
  }

  Future<void> setReturnReportType(String type) async {
    selectedReturnReportType = type;
    selectedReturnReportCustomerId = null;
    selectedReturnReportSupplierId = null;
    notifyListeners();
    await loadGenericReport('returns');
  }

  Future<List<int>?> exportSalesReport() async {
    List<int>? bytes;
    await _runBusy(() async {
      bytes = await _reportRepository.exportSalesReport(
        range: selectedReportRange,
        from: customReportRange?.start,
        to: _exclusiveEnd(customReportRange?.end),
        productId: selectedReportProductId,
        categoryId: selectedReportCategoryId,
        customerId: selectedReportCustomerId,
      );
    });
    return bytes;
  }

  List<FeatureRecord> featureRecords(String path) {
    return List.unmodifiable(_featureRecords[path] ?? const []);
  }

  bool canLoadMoreFeatureRecords(String path, {Map<String, String>? query}) {
    if (_featureNextCursors[path] == null) return false;
    if (query == null) return true;
    return _featureQueryKeys[path] == _queryKey(query);
  }

  bool get canLoadMoreProducts => _productNextCursor != null;
  bool get canLoadMoreCustomers => _customerNextCursor != null;

  Future<void> setProductCategoryFilter(int? categoryId) async {
    selectedProductCategoryFilterId = categoryId;
    await _runBusy(_loadProductPage);
  }

  Future<void> setProductLocationFilter(int? locationId) async {
    selectedProductLocationFilterId = locationId;
    await _runBusy(_loadProductPage);
  }

  Future<void> setProductStockFilter(String filter) async {
    selectedProductStockFilter = filter;
    await _runBusy(_loadProductPage);
  }

  Future<void> loadMoreProducts() async {
    final cursor = _productNextCursor;
    if (cursor == null) return;
    await _runBusy(() async {
      final page = await _productRepository.fetchProductPage(
        query: productSearch,
        categoryId: selectedProductCategoryFilterId,
        locationId: selectedProductLocationFilterId,
        stockFilter: selectedProductStockFilter == 'all'
            ? null
            : selectedProductStockFilter,
        cursor: cursor,
      );
      _products = [..._products, ...page.rows];
      _productNextCursor = page.nextCursor;
    });
  }

  Future<bool> loadMoreCustomers({String? query}) async {
    final cursor = _customerNextCursor;
    if (cursor == null) return false;
    await _runBusy(() async {
      final page = await _customerRepository.fetchCustomerPage(
        query: query,
        cursor: cursor,
      );
      _customers = [..._customers, ...page.rows];
      _customerNextCursor = page.nextCursor;
    });
    return true;
  }

  Future<void> loadFeatureRecords(
    String path, {
    Map<String, String>? query,
    bool force = false,
  }) async {
    final cacheKey = _queryKey(query);
    if (!force &&
        _featureRecords.containsKey(path) &&
        _featureQueryKeys[path] == cacheKey) {
      return;
    }

    final loadKey = '$path?$cacheKey';
    final existingLoad = _featureLoadFutures[loadKey];
    if (existingLoad != null) {
      await existingLoad;
      return;
    }

    late Future<void> load;
    load = _runBusy(() async {
      final page = await _featureRepository.listPage(path, query: query);
      _featureRecords[path] = page.rows;
      _featureNextCursors[path] = page.nextCursor;
      _featureQueryKeys[path] = cacheKey;
    });
    _featureLoadFutures[loadKey] = load;
    try {
      await load;
    } finally {
      _featureLoadFutures.remove(loadKey);
    }
  }

  Future<void> loadMoreFeatureRecords(
    String path, {
    Map<String, String>? query,
  }) async {
    final cursor = _featureNextCursors[path];
    if (cursor == null) return;
    final nextQuery = {...?query, 'cursor': cursor};
    final baseCacheKey = _queryKey(query);
    final loadKey = '$path?more:${_queryKey(nextQuery)}';
    final existingLoad = _featureLoadFutures[loadKey];
    if (existingLoad != null) {
      await existingLoad;
      return;
    }
    late Future<void> load;
    load = _runBusy(() async {
      final page = await _featureRepository.listPage(path, query: nextQuery);
      final current = _featureRecords[path] ?? const <FeatureRecord>[];
      _featureRecords[path] = [...current, ...page.rows];
      _featureNextCursors[path] = page.nextCursor;
      _featureQueryKeys[path] = baseCacheKey;
    });
    _featureLoadFutures[loadKey] = load;
    try {
      await load;
    } finally {
      _featureLoadFutures.remove(loadKey);
    }
  }

  Future<FeatureRecord?> saveFeatureRecord(
    String path,
    Map<String, Object?> body, {
    int? id,
  }) async {
    FeatureRecord? saved;
    await _runBusy(() async {
      saved = await _featureRepository.save(path, body, id: id);
      final page = await _featureRepository.listPage(path);
      _featureRecords[path] = page.rows;
      _featureNextCursors[path] = page.nextCursor;
      _featureQueryKeys[path] = _queryKey(null);
      if (path.contains('purchases') ||
          path.contains('returns') ||
          path == '/api/stock' ||
          path == '/api/cash-entries') {
        await _loadProductPage();
        _invalidateReports();
      }
    });
    return saved;
  }

  Future<void> saveCustomerGroupDiscounts(
    List<Map<String, Object?>> items, {
    List<int> deleteIds = const [],
  }) async {
    await _runBusy(() async {
      await _featureRepository.saveBatch(
        '/api/customer-group-discounts',
        items,
        deleteIds: deleteIds,
      );
      final page = await _featureRepository.listPage(
        '/api/customer-group-discounts',
      );
      _featureRecords['/api/customer-group-discounts'] = page.rows;
      _featureNextCursors['/api/customer-group-discounts'] = page.nextCursor;
      _featureQueryKeys['/api/customer-group-discounts'] = _queryKey(null);
    });
  }

  Future<void> deleteFeatureRecord(String path, FeatureRecord record) async {
    await _runBusy(() async {
      await _featureRepository.delete(path, record.id);
      final page = await _featureRepository.listPage(path);
      _featureRecords[path] = page.rows;
      _featureNextCursors[path] = page.nextCursor;
      _featureQueryKeys[path] = _queryKey(null);
      _invalidateReports();
    });
  }

  Future<List<FeatureRecord>> loadGenericReport(
    String kind, {
    String? search,
  }) async {
    selectedGenericReport = kind;
    final path = '/api/reports/$kind';
    await loadFeatureRecords(
      path,
      query: _reportQuery(kind: kind, search: search),
    );
    return featureRecords(path);
  }

  Future<void> loadMoreGenericReport(String kind, {String? search}) async {
    await loadMoreFeatureRecords(
      '/api/reports/$kind',
      query: _reportQuery(kind: kind, search: search),
    );
  }

  Future<List<int>?> exportGenericReport(String kind, {String? search}) async {
    List<int>? bytes;
    await _runBusy(() async {
      bytes = await _featureRepository.exportReport(
        kind,
        _reportQuery(kind: kind, search: search),
      );
    });
    return bytes;
  }

  Map<String, String> reportQueryFor(String kind, {String? search}) =>
      _reportQuery(kind: kind, search: search);

  Map<String, String> _reportQuery({String? kind, String? search}) {
    final reportKind = kind ?? 'all-transactions';
    final range = reportRangeFor(reportKind);
    final customRange = customReportRangeFor(reportKind);
    final type = selectedReportTypeFor(reportKind);
    final categoryId = selectedReportCategoryIdFor(reportKind);
    final productId = categoryId == null
        ? null
        : selectedReportProductIdFor(reportKind);
    final isSalesType = type == 'penjualan' || type == 'retur penjualan';
    final isPurchaseType = type == 'pembelian' || type == 'retur pembelian';
    final rangeQuery = _reportRepository.rangeQuery(
      range,
      from: customRange?.start,
      to: _exclusiveEnd(customRange?.end),
      productId: productId,
      categoryId: categoryId,
      customerId: isSalesType ? selectedReportCustomerIdFor(reportKind) : null,
    );
    if (type != 'all') {
      rangeQuery['type'] = type;
    }
    final supplierId = isPurchaseType
        ? selectedReportSupplierIdFor(reportKind)
        : null;
    if (supplierId != null) {
      rangeQuery['supplier_id'] = supplierId.toString();
    }
    final searchText = search?.trim();
    if (searchText != null && searchText.isNotEmpty) {
      rangeQuery['search'] = searchText;
    }
    return rangeQuery;
  }

  DateTime? _exclusiveEnd(DateTime? date) {
    if (date == null) return null;
    return DateTime(date.year, date.month, date.day + 1);
  }

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
    final start = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
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

  String _queryKey(Map<String, String>? query) {
    if (query == null || query.isEmpty) return '';
    final keys = query.keys.toList()..sort();
    return keys.map((key) => '$key=${query[key]}').join('&');
  }

  void _invalidateReports() {
    final reportPaths = _featureRecords.keys
        .where((path) => path.startsWith('/api/reports/'))
        .toList(growable: false);
    for (final path in reportPaths) {
      _featureRecords.remove(path);
      _featureQueryKeys.remove(path);
      _featureNextCursors.remove(path);
    }
  }

  Future<void> _loadProductPage() async {
    final page = await _productRepository.fetchProductPage(
      query: productSearch,
      categoryId: selectedProductCategoryFilterId,
      locationId: selectedProductLocationFilterId,
      stockFilter: selectedProductStockFilter == 'all'
          ? null
          : selectedProductStockFilter,
    );
    _products = page.rows;
    _productNextCursor = page.nextCursor;
  }

  Future<void> _loadCustomerPage({String? query}) async {
    final page = await _customerRepository.fetchCustomerPage(query: query);
    _customers = page.rows;
    _customerNextCursor = page.nextCursor;
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    final wasIdle = _busyDepth == 0;
    _busyDepth++;
    if (wasIdle) {
      isBusy = true;
      errorMessage = null;
      notifyListeners();
    }
    try {
      await action();
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      _busyDepth--;
      if (_busyDepth < 0) _busyDepth = 0;
      if (_busyDepth == 0) {
        isBusy = false;
        notifyListeners();
      }
    }
  }
}
