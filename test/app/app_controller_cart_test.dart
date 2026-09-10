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
