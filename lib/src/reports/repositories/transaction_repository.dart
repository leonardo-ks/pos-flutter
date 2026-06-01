import '../../auth/models/app_user.dart';
import '../../customers/models/customer.dart';
import '../../pos/models/cart_line.dart';
import '../../shared/api/api_client.dart';
import '../../shared/data/mock_data_store.dart';
import '../models/sale_transaction.dart';
import '../models/transaction_item.dart';

abstract class TransactionRepository {
  Future<List<SaleTransaction>> fetchTransactions({
    required AppUser user,
    required List<Customer> customers,
  });

  Future<SaleTransaction> createTransaction({
    required AppUser user,
    required Customer? customer,
    required List<CartLine> lines,
    String paymentMethod = 'cash',
    double? cashReceived,
    double? discountAmount,
  });
}

class MockTransactionRepository implements TransactionRepository {
  MockTransactionRepository(this._store);

  final MockDataStore _store;

  @override
  Future<List<SaleTransaction>> fetchTransactions({
    required AppUser user,
    required List<Customer> customers,
  }) async {
    final transactions = List<SaleTransaction>.from(_store.transactions);
    transactions.sort((a, b) => b.time.compareTo(a.time));
    return transactions;
  }

  @override
  Future<SaleTransaction> createTransaction({
    required AppUser user,
    required Customer? customer,
    required List<CartLine> lines,
    String paymentMethod = 'cash',
    double? cashReceived,
    double? discountAmount,
  }) async {
    final subtotal = lines.fold<double>(
      0,
      (total, line) => total + line.subtotal,
    );
    final discount = discountAmount ?? 0;
    final totalFinal = subtotal - discount;
    final received = paymentMethod == 'cash'
        ? cashReceived ?? totalFinal
        : totalFinal;
    final transaction = SaleTransaction(
      id: _nextId(),
      time: DateTime.now(),
      customer: customer,
      user: user,
      items: lines
          .map(
            (line) => TransactionItem(
              productId: line.product.id,
              productName: line.product.name,
              unitPrice: line.product.price,
              quantity: line.quantity,
            ),
          )
          .toList(growable: false),
      totalBeforeDiscount: subtotal,
      discount: discount,
      totalFinal: totalFinal,
      paymentMethod: paymentMethod,
      paidAmount: paymentMethod == 'cash'
          ? received.clamp(0, totalFinal).toDouble()
          : totalFinal,
      cashReceived: received,
      changeAmount: paymentMethod == 'cash'
          ? (received - totalFinal).clamp(0, double.infinity).toDouble()
          : 0,
    );

    _store.transactions.add(transaction);
    for (final line in lines) {
      final index = _store.products.indexWhere(
        (item) => item.id == line.product.id,
      );
      if (index == -1) continue;
      final product = _store.products[index];
      final nextStock = (product.stock - line.quantity)
          .clamp(0, product.stock)
          .toInt();
      _store.products[index] = product.copyWith(stock: nextStock);
    }
    return transaction;
  }

  int _nextId() {
    if (_store.transactions.isEmpty) return 1001;
    return _store.transactions
            .map((transaction) => transaction.id)
            .reduce((a, b) => a > b ? a : b) +
        1;
  }
}

class ApiTransactionRepository implements TransactionRepository {
  ApiTransactionRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<SaleTransaction>> fetchTransactions({
    required AppUser user,
    required List<Customer> customers,
  }) {
    return _apiClient.get<List<SaleTransaction>>('/api/transactions', (data) {
      final rows = data is Map && data['rows'] is List
          ? data['rows'] as List
          : data as List;
      return rows
          .map((item) {
            final map = (item as Map).cast<String, Object?>();
            final customerId = map['customer_id'] as int?;
            return SaleTransaction.fromJson(
              map,
              user: user,
              customer: customerId == null
                  ? null
                  : customers
                        .where((customer) => customer.id == customerId)
                        .firstOrNull,
            );
          })
          .toList(growable: false);
    });
  }

  @override
  Future<SaleTransaction> createTransaction({
    required AppUser user,
    required Customer? customer,
    required List<CartLine> lines,
    String paymentMethod = 'cash',
    double? cashReceived,
    double? discountAmount,
  }) {
    final body = <String, Object?>{
      'customer_id': customer?.id,
      'items': [
        for (final line in lines)
          {'product_id': line.product.id, 'jumlah_beli': line.quantity},
      ],
      'payment_method': paymentMethod,
    };
    if (cashReceived != null) body['cash_received'] = cashReceived;
    return _apiClient.post<SaleTransaction>(
      '/api/transactions',
      body,
      (data) => SaleTransaction.fromJson(
        (data as Map).cast<String, Object?>(),
        user: user,
        customer: customer,
      ),
    );
  }
}
