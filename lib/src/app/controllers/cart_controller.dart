import 'package:flutter/foundation.dart';

import '../../customers/models/customer.dart';
import '../../inventory/models/product.dart';
import '../../pos/models/cart_line.dart';
import '../../shared/models/feature_record.dart';

class CartController extends ChangeNotifier {
  CartController({
    required List<Product> Function() liveProducts,
    required Customer? Function() selectedCustomer,
    required List<FeatureRecord> Function() customerGroupDiscounts,
    required bool Function() isBusy,
  })  :
        // ignore: prefer_initializing_formals
        _liveProducts = liveProducts,
        // ignore: prefer_initializing_formals
        _selectedCustomer = selectedCustomer,
        // ignore: prefer_initializing_formals
        _customerGroupDiscounts = customerGroupDiscounts,
        // ignore: prefer_initializing_formals
        _isBusy = isBusy;

  final List<Product> Function() _liveProducts;
  final Customer? Function() _selectedCustomer;
  final List<FeatureRecord> Function() _customerGroupDiscounts;
  final bool Function() _isBusy;

  final Map<int, int> _cart = {};
  final Map<int, Product> _cartProducts = {};
  String _paymentMethod = 'cash';
  double _cashReceived = 0;

  String get paymentMethod => _paymentMethod;
  double get cashReceived => _cashReceived;

  List<CartLine> get lines {
    return _cart.entries
        .map((entry) {
          final product = _liveProducts()
                  .where((item) => item.id == entry.key)
                  .firstOrNull ??
              _cartProducts[entry.key];
          if (product == null) return null;
          return CartLine(product: product, quantity: entry.value);
        })
        .whereType<CartLine>()
        .toList(growable: false);
  }

  double get subtotal => lines.fold(0, (t, l) => t + l.subtotal);

  double get discountAmount {
    if (_selectedCustomer() == null) return 0;
    return lines.fold<double>(
      0,
      (t, l) => t + l.subtotal * discountRateForProduct(l.product),
    );
  }

  double get grandTotal => subtotal - discountAmount;

  double get cashChange =>
      _paymentMethod == 'cash' ? _cashReceived - grandTotal : 0;

  bool get canCheckout {
    if (lines.isEmpty || _isBusy()) return false;
    if (_paymentMethod != 'cash') return true;
    return _cashReceived >= grandTotal;
  }

  double discountRateForProduct(Product product, {Customer? customer}) {
    final effectiveCustomer = customer ?? _selectedCustomer();
    if (effectiveCustomer == null || product.categoryId == null) return 0;
    final match = _customerGroupDiscounts().where(
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

  void addToCart(Product product) {
    final q = _cart[product.id] ?? 0;
    if (q >= product.stock) return;
    _cartProducts[product.id] = product;
    _cart[product.id] = q + 1;
    notifyListeners();
  }

  void decrementCart(Product product) {
    final q = _cart[product.id] ?? 0;
    if (q <= 1) {
      _cart.remove(product.id);
      _cartProducts.remove(product.id);
    } else {
      _cart[product.id] = q - 1;
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

  void selectPaymentMethod(String value) {
    _paymentMethod = value;
    _cashReceived = value == 'cash' ? _cashReceived : grandTotal;
    notifyListeners();
  }

  void setCashReceived(String value) {
    _cashReceived =
        double.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    notifyListeners();
  }

  List<CartLine> takeLinesForCheckout() => lines;

  void clearAfterCheckout() {
    _cart.clear();
    _cartProducts.clear();
    _cashReceived = 0;
    notifyListeners();
  }

  void reset() {
    _cart.clear();
    _cartProducts.clear();
    _paymentMethod = 'cash';
    _cashReceived = 0;
    notifyListeners();
  }
}
