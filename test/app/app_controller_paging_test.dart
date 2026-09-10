import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_flutter/src/app/app_controller.dart';
import 'package:pos_flutter/src/auth/models/app_user.dart';
import 'package:pos_flutter/src/customers/repositories/customer_repository.dart';
import 'package:pos_flutter/src/inventory/models/product.dart';
import 'package:pos_flutter/src/inventory/repositories/product_repository.dart';

import 'fakes.dart';

Product _product(int id, {String name = 'P', int stock = 5}) => Product(
      id: id,
      name: name,
      sku: 'SKU-$id',
      price: 1000,
      stock: stock,
    );

void main() {
  test('loadMoreProducts appends and advances the cursor, then stops', () async {
    final p1 = _product(1, name: 'One');
    final p2 = _product(2, name: 'Two');
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
    // The gated call is the FIRST *search* call ('a'); login already consumed
    // one plain fetchProductPage. 'a' resolves only after 'b' is issued, so
    // AppController.setProductSearch's guard `if (productSearch != value) return;`
    // must discard the stale 'a' result and keep 'b'.
    final gate = Completer<void>();
    final repo = _StaleProductRepo(gate);
    final c = AppController(productRepository: repo);
    await c.loginAsRoleForTest(UserRole.manager);

    c.setProductSearch('a'); // in flight, blocked on gate
    c.setProductSearch('b'); // resolves immediately with [B]
    gate.complete(); // now let 'a' resolve with [A-STALE]
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

/// Inline fake for the stale-response test. Call #1 is login's plain page load
/// (returns empty). Call #2 (search 'a') is gated on [_gate] and yields a
/// product named 'A-STALE'. Call #3 (search 'b') returns immediately with 'B'.
class _StaleProductRepo implements ProductRepository {
  _StaleProductRepo(this._gate);
  final Completer<void> _gate;
  int calls = 0;

  @override
  Future<PagedProducts> fetchProductPage({
    String? query,
    int? categoryId,
    int? locationId,
    String? stockFilter,
    String? cursor,
  }) async {
    calls++;
    final n = calls;
    if (n == 2) {
      await _gate.future;
      return PagedProducts(
        rows: [_product(91, name: 'A-STALE')],
        nextCursor: null,
      );
    }
    if (n == 3) {
      return PagedProducts(rows: [_product(92, name: 'B')], nextCursor: null);
    }
    return const PagedProducts(rows: [], nextCursor: null);
  }

  @override
  Future<List<Product>> fetchProducts({String? query}) async => const [];
  @override
  Future<Product> upsertProduct(Product product) => throw UnimplementedError();
  @override
  Future<void> deleteProduct(int id) => throw UnimplementedError();
}
