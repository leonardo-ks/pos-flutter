import 'package:flutter/foundation.dart';

import '../../inventory/models/product.dart';
import '../../inventory/repositories/product_repository.dart';
import '../async_guard.dart';

class ProductController extends ChangeNotifier {
  ProductController(
    this._guard,
    this._repo, {
    List<Product> initialItems = const [],
  }) : _items = initialItems;

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
