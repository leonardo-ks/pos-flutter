class TransactionItem {
  const TransactionItem({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
  });

  final int productId;
  final String productName;
  final double unitPrice;
  final int quantity;

  factory TransactionItem.fromJson(Map<String, Object?> json) {
    return TransactionItem(
      productId: json['product_id'] as int,
      productName: (json['nama_produk'] ?? json['productName']) as String,
      unitPrice: (json['harga_satuan'] as num).toDouble(),
      quantity: json['jumlah_beli'] as int,
    );
  }

  double get subtotal => unitPrice * quantity;
}
