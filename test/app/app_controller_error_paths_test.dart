// Error-path characterization tests for AppController. These pin the failure
// semantics that changed when login()/checkout()/refreshData() moved from bare
// _loadProductPage()/_loadCustomerPage() (throws propagate, abort the method) to
// products.reload()/customers.reload() (nested AsyncGuard.run catches the throw
// into errorMessage and returns normally). See the design doc's
// "Post-implementation note: failure semantics of guard-nested reloads".
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_flutter/src/app/app_controller.dart';
import 'package:pos_flutter/src/auth/models/app_user.dart';
import 'package:pos_flutter/src/inventory/models/product.dart';
import 'package:pos_flutter/src/inventory/repositories/product_repository.dart';

import 'fakes.dart';

Product _product(int id, {int stock = 5}) =>
    Product(id: id, name: 'P$id', sku: 'SKU-$id', price: 1000, stock: stock);

void main() {
  test(
    'A: login continues past a failed product reload and still loads '
    'role-permissions',
    () async {
      final products = FakeProductRepository()..throwNext = StateError('boom');
      final feat = FakeFeatureRepository();
      final c = AppController(
        productRepository: products,
        featureRepository: feat,
      );

      await c.loginAsRoleForTest(UserRole.administrator);

      expect(c.session.isLoggedIn, isTrue);
      expect(c.errorMessage, isNotNull); // throw captured, not rethrown
      // login did NOT abort early on the product-endpoint failure:
      expect(feat.listedPaths, contains('/api/role-permissions'));
    },
  );

  test('B: checkout clears the cart even if the post-sale reload fails', () async {
    final products = FakeProductRepository(
      pages: [
        PagedProducts(rows: [_product(1)], nextCursor: null),
      ],
    );
    final c = AppController(productRepository: products);
    await c.loginAsRoleForTest(UserRole.cashier);

    c.customers.select(c.customers.items.first);
    c.cart.addToCart(c.products.items.first);

    // Arm the throw so products.reload() inside checkout() (post-sale refresh)
    // blows up on fetchProductPage.
    products.throwNext = StateError('post-sale reload boom');
    final tx = await c.checkout();

    expect(tx, isNotNull); // sale committed
    expect(c.cart.lines, isEmpty); // cart cleared despite the failed refresh
    expect(c.customers.selected, isNull);
  });

  test('C: standalone refreshData() flips isBusy and clears errorMessage', () async {
    final products = FakeProductRepository(
      pages: [
        PagedProducts(rows: [_product(1)], nextCursor: null),
      ],
    );
    final c = AppController(productRepository: products);
    await c.loginAsRoleForTest(UserRole.manager);

    // Force a stale errorMessage via a failed reload.
    products.throwNext = StateError('stale');
    await c.products.reload();
    expect(c.errorMessage, isNotNull);

    var sawBusy = false;
    void listener() {
      if (c.isBusy) sawBusy = true;
    }

    c.addListener(listener);
    await c.refreshData();
    c.removeListener(listener);

    expect(sawBusy, isTrue); // busy spinner shown during the manual refresh
    expect(c.errorMessage, isNull); // stale error cleared
  });
}
