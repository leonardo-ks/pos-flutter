import '../../shared/api/api_client.dart';
import '../../shared/data/mock_data_store.dart';
import '../models/product.dart';

abstract class ProductRepository {
  Future<PagedProducts> fetchProductPage({
    String? query,
    int? categoryId,
    int? locationId,
    String? stockFilter,
    String? cursor,
  });
  Future<List<Product>> fetchProducts({String? query});
  Future<Product> upsertProduct(Product product);
  Future<void> deleteProduct(int id);
}

class PagedProducts {
  const PagedProducts({required this.rows, this.nextCursor});

  final List<Product> rows;
  final String? nextCursor;
}

class MockProductRepository implements ProductRepository {
  MockProductRepository(this._store);

  final MockDataStore _store;

  @override
  Future<PagedProducts> fetchProductPage({
    String? query,
    int? categoryId,
    int? locationId,
    String? stockFilter,
    String? cursor,
  }) async {
    final rows = await fetchProducts(query: query);
    return PagedProducts(rows: rows, nextCursor: null);
  }

  @override
  Future<List<Product>> fetchProducts({String? query}) async {
    final normalized = query?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty) return List.unmodifiable(_store.products);
    return _store.products
        .where(
          (product) =>
              product.name.toLowerCase().contains(normalized) ||
              product.sku.toLowerCase().contains(normalized),
        )
        .toList(growable: false);
  }

  @override
  Future<Product> upsertProduct(Product product) async {
    final index = _store.products.indexWhere((item) => item.id == product.id);
    if (index == -1 || product.id == 0) {
      final nextId = _store.products.isEmpty
          ? 1
          : _store.products
                    .map((item) => item.id)
                    .reduce((a, b) => a > b ? a : b) +
                1;
      final saved = product.copyWith(id: nextId);
      _store.products.add(saved);
      return saved;
    }

    _store.products[index] = product;
    return product;
  }

  @override
  Future<void> deleteProduct(int id) async {
    _store.products.removeWhere((product) => product.id == id);
  }
}

class ApiProductRepository implements ProductRepository {
  ApiProductRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<PagedProducts> fetchProductPage({
    String? query,
    int? categoryId,
    int? locationId,
    String? stockFilter,
    String? cursor,
  }) {
    final params = <String, String>{};
    params['limit'] = '24';
    final search = query?.trim();
    if (search != null && search.isNotEmpty) params['q'] = search;
    if (categoryId != null) params['category_id'] = categoryId.toString();
    if (locationId != null) params['location_id'] = locationId.toString();
    if (stockFilter != null && stockFilter.isNotEmpty) {
      params['stock_filter'] = stockFilter;
    }
    if (cursor != null && cursor.isNotEmpty) params['cursor'] = cursor;
    return _apiClient.get<PagedProducts>('/api/products', (data) {
      final map = data as Map;
      final rows = (map['rows'] as List)
          .map(
            (item) => Product.fromJson((item as Map).cast<String, Object?>()),
          )
          .toList(growable: false);
      return PagedProducts(
        rows: rows,
        nextCursor: map['next_cursor'] as String?,
      );
    }, query: params.isEmpty ? null : params);
  }

  @override
  Future<List<Product>> fetchProducts({String? query}) {
    return fetchProductPage(query: query).then((page) => page.rows);
  }

  @override
  Future<Product> upsertProduct(Product product) {
    if (product.id == 0) {
      return _apiClient.post<Product>(
        '/api/products',
        product.toApiJson(),
        (data) => Product.fromJson((data as Map).cast<String, Object?>()),
      );
    }
    return _apiClient.patch<Product>(
      '/api/products/${product.id}',
      product.toApiJson(),
      (data) => Product.fromJson((data as Map).cast<String, Object?>()),
    );
  }

  @override
  Future<void> deleteProduct(int id) async {
    await _apiClient.delete<void>('/api/products/$id', (_) {});
  }
}
