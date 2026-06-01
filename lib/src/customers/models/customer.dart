class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.discountCategory,
  });

  final int id;
  final String name;
  final String phone;
  final String discountCategory;

  factory Customer.fromJson(Map<String, Object?> json) {
    return Customer(
      id: json['id'] as int,
      name: json['nama'] as String,
      phone: json['phone'] as String,
      discountCategory: json['kategori_diskon'] as String,
    );
  }

  Map<String, Object?> toApiJson() {
    return {'nama': name, 'phone': phone, 'kategori_diskon': discountCategory};
  }

  double get discountRate {
    return switch (discountCategory.toLowerCase()) {
      'vip' => 0.10,
      'gold' => 0.15,
      _ => 0,
    };
  }

  Customer copyWith({
    int? id,
    String? name,
    String? phone,
    String? discountCategory,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      discountCategory: discountCategory ?? this.discountCategory,
    );
  }
}
