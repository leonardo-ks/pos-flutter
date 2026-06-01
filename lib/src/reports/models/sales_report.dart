class SalesReport {
  const SalesReport({
    required this.revenue,
    required this.transactionCount,
    required this.itemCount,
    required this.topProducts,
    required this.recentTransactions,
  });

  final double revenue;
  final int transactionCount;
  final int itemCount;
  final List<TopProduct> topProducts;
  final List<RecentSale> recentTransactions;

  factory SalesReport.empty() {
    return const SalesReport(
      revenue: 0,
      transactionCount: 0,
      itemCount: 0,
      topProducts: [],
      recentTransactions: [],
    );
  }

  factory SalesReport.fromJson(Map<String, Object?> json) {
    final summary = json['summary'] as Map<String, Object?>;
    return SalesReport(
      revenue: (summary['revenue'] as num).toDouble(),
      transactionCount: summary['transaction_count'] as int,
      itemCount: summary['item_count'] as int,
      topProducts: (json['top_products'] as List)
          .map(
            (item) =>
                TopProduct.fromJson((item as Map).cast<String, Object?>()),
          )
          .toList(growable: false),
      recentTransactions: (json['recent_transactions'] as List)
          .map(
            (item) =>
                RecentSale.fromJson((item as Map).cast<String, Object?>()),
          )
          .toList(growable: false),
    );
  }
}

class TopProduct {
  const TopProduct({
    required this.productId,
    required this.name,
    required this.quantitySold,
    required this.revenue,
  });

  final int productId;
  final String name;
  final int quantitySold;
  final double revenue;

  factory TopProduct.fromJson(Map<String, Object?> json) {
    return TopProduct(
      productId: json['product_id'] as int,
      name: json['nama_produk'] as String,
      quantitySold: json['quantity_sold'] as int,
      revenue: (json['revenue'] as num).toDouble(),
    );
  }
}

class RecentSale {
  const RecentSale({
    required this.id,
    required this.time,
    required this.customerName,
    required this.cashierName,
    required this.totalFinal,
  });

  final int id;
  final DateTime time;
  final String? customerName;
  final String cashierName;
  final double totalFinal;

  factory RecentSale.fromJson(Map<String, Object?> json) {
    return RecentSale(
      id: json['id'] as int,
      time: DateTime.parse((json['created_at'] ?? json['waktu']) as String),
      customerName: json['customer_name'] as String?,
      cashierName: json['cashier_name'] as String,
      totalFinal: (json['total_akhir'] as num).toDouble(),
    );
  }
}
