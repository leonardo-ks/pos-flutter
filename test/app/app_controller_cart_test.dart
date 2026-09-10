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
    final p = c.products.items.first;
    for (var i = 0; i < p.stock + 5; i++) {
      c.cart.addToCart(p);
    }
    final line = c.cart.lines.firstWhere((l) => l.product.id == p.id);
    expect(line.quantity, p.stock);
  });

  test('decrementCart removes the line at quantity 1', () {
    final p = c.products.items.first;
    c.cart.addToCart(p);
    c.cart.decrementCart(p);
    expect(c.cart.lines.where((l) => l.product.id == p.id), isEmpty);
  });

  test('setCartQuantity clamps into 1..stock', () {
    final p = c.products.items.first;
    c.cart.setCartQuantity(p, '99999');
    expect(c.cart.lines.first.quantity, p.stock);
    c.cart.setCartQuantity(p, '0');
    expect(c.cart.lines, isEmpty);
  });

  test('VIP discount math matches widget_test expectation', () {
    c.customers.select(c.customers.items.first);
    c.cart.addToCart(c.products.items.first);
    expect(c.cart.discountAmount, 1800);
    expect(c.cart.grandTotal, 16200);
  });

  test('cashChange only applies for cash payment', () {
    c.cart.addToCart(c.products.items.first);
    c.cart.setCashReceived('20000');
    expect(c.cart.cashChange, 20000 - c.cart.grandTotal);
    c.cart.selectPaymentMethod('transfer');
    expect(c.cart.cashChange, 0);
  });

  test('canCheckout gates', () {
    expect(c.cart.canCheckout, isFalse);
    c.cart.addToCart(c.products.items.first);
    c.cart.setCashReceived('1');
    expect(c.cart.canCheckout, isFalse);
    c.cart.setCashReceived('999999');
    expect(c.cart.canCheckout, isTrue);
    c.cart.selectPaymentMethod('transfer');
    expect(c.cart.canCheckout, isTrue);
  });
}
