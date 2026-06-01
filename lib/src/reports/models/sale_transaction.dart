import '../../auth/models/app_user.dart';
import '../../customers/models/customer.dart';
import 'transaction_item.dart';

class SaleTransaction {
  const SaleTransaction({
    required this.id,
    required this.time,
    required this.customer,
    required this.user,
    required this.items,
    required this.totalBeforeDiscount,
    required this.discount,
    required this.totalFinal,
    this.paymentMethod = 'cash',
    this.paidAmount,
    this.cashReceived,
    this.changeAmount = 0,
  });

  final int id;
  final DateTime time;
  final Customer? customer;
  final AppUser user;
  final List<TransactionItem> items;
  final double totalBeforeDiscount;
  final double discount;
  final double totalFinal;
  final String paymentMethod;
  final double? paidAmount;
  final double? cashReceived;
  final double changeAmount;

  int get itemCount => items.fold(0, (total, item) => total + item.quantity);

  factory SaleTransaction.fromJson(
    Map<String, Object?> json, {
    required AppUser user,
    Customer? customer,
  }) {
    final rawItems = json['items'];
    return SaleTransaction(
      id: json['id'] as int,
      time: DateTime.parse((json['created_at'] ?? json['waktu']) as String),
      customer: customer,
      user: user,
      items: rawItems is List
          ? rawItems
                .cast<Map<String, Object?>>()
                .map(TransactionItem.fromJson)
                .toList(growable: false)
          : const [],
      totalBeforeDiscount: (json['subtotal'] as num).toDouble(),
      discount: (json['discount_amount'] as num).toDouble(),
      totalFinal: (json['total_akhir'] as num).toDouble(),
      paymentMethod: json['payment_method'] as String? ?? 'cash',
      paidAmount: (json['paid_amount'] as num?)?.toDouble(),
      cashReceived: (json['cash_received'] as num?)?.toDouble(),
      changeAmount: (json['change_amount'] as num?)?.toDouble() ?? 0,
    );
  }
}
