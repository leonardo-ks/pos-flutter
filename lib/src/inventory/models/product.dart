class Product {
  const Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.price,
    required this.stock,
    this.purchasePrice = 0,
    this.supplierId,
    this.categoryId,
    this.barcode,
    this.supplierName,
    this.categoryName,
    this.description,
  });

  final int id;
  final String name;
  final String sku;
  final double price;
  final int stock;
  final double purchasePrice;
  final int? supplierId;
  final int? categoryId;
  final String? barcode;
  final String? supplierName;
  final String? categoryName;
  final String? description;

  factory Product.fromJson(Map<String, Object?> json) {
    return Product(
      id: json['id'] as int,
      name: json['nama_produk'] as String,
      sku: json['sku'] as String,
      price: (json['harga'] as num).toDouble(),
      stock: json['stok'] as int,
      purchasePrice: ((json['harga_beli'] as num?) ?? 0).toDouble(),
      supplierId: (json['supplier_id'] as num?)?.toInt(),
      categoryId: (json['category_id'] as num?)?.toInt(),
      barcode: json['barcode'] as String?,
      supplierName: json['supplier_name'] as String?,
      categoryName: json['category_name'] as String?,
      description: json['keterangan'] as String?,
    );
  }

  Map<String, Object?> toApiJson() {
    return {
      'nama_produk': name,
      'sku': sku,
      'harga': price,
      'stok': stock,
      'harga_beli': purchasePrice,
      'supplier_id': supplierId,
      'category_id': categoryId,
      'barcode': barcode,
      'keterangan': description ?? '',
    };
  }

  Product copyWith({
    int? id,
    String? name,
    String? sku,
    double? price,
    int? stock,
    double? purchasePrice,
    int? supplierId,
    int? categoryId,
    String? barcode,
    String? supplierName,
    String? categoryName,
    String? description,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      supplierId: supplierId ?? this.supplierId,
      categoryId: categoryId ?? this.categoryId,
      barcode: barcode ?? this.barcode,
      supplierName: supplierName ?? this.supplierName,
      categoryName: categoryName ?? this.categoryName,
      description: description ?? this.description,
    );
  }
}
