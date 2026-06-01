import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_flutter/src/app/app_controller.dart';
import 'package:pos_flutter/src/app/pos_kasir_app.dart';
import 'package:pos_flutter/src/auth/models/app_user.dart';

void main() {
  testWidgets('Kasir tidak melihat menu laporan', (tester) async {
    final controller = AppController();
    await tester.pumpWidget(PosKasirApp(controller: controller));

    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Kasir'), findsWidgets);
    expect(find.text('Master'), findsWidgets);
    expect(find.text('Laporan'), findsNothing);
    controller.selectSection(AppSection.reports);
    expect(controller.selectedSection, AppSection.pos);
  });

  testWidgets('Manajer dapat membuka laporan', (tester) async {
    final controller = AppController();
    await tester.pumpWidget(PosKasirApp(controller: controller));

    await tester.enterText(find.byKey(const Key('login-username')), 'manajer');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Laporan'));
    await tester.pumpAndSettle();

    expect(find.text('Penjualan/Pembelian'), findsWidgets);
    expect(find.text('Retur'), findsWidgets);
  });

  testWidgets('Diskon VIP diterapkan ke total keranjang', (tester) async {
    final controller = AppController();
    await controller.loginAsRoleForTest(UserRole.cashier);
    await tester.pumpWidget(PosKasirApp(controller: controller));

    controller.selectCustomer(controller.customers.first);
    controller.addToCart(controller.products.first);
    await tester.pumpAndSettle();

    expect(controller.discountAmount, 1800);
    expect(controller.grandTotal, 16200);
  });

  testWidgets('Checkout mengurangi stok dan membuat transaksi', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final controller = AppController();
    await tester.pumpWidget(PosKasirApp(controller: controller));

    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    final initialTransactions = controller.transactions.length;
    final initialStock = controller.products.first.stock;

    await tester.tap(find.byKey(const Key('add-product-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('cash-received-input')),
      '20000',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('checkout-button')));
    await tester.pumpAndSettle();

    expect(find.text('Transaksi Berhasil'), findsOneWidget);
    expect(controller.transactions.length, initialTransactions + 1);
    expect(controller.products.first.stock, initialStock - 1);
  });
}
