class LocalProduct {
  const LocalProduct({
    required this.id,
    required this.name,
    this.sku,
    this.barcode,
    this.category,
    this.price,
    this.quantity,
    this.lowStockThreshold,
  });

  final String id;
  final String name;
  final String? sku;
  final String? barcode;
  final String? category;
  final num? price;
  final num? quantity;
  final num? lowStockThreshold;

  bool get isLowStock =>
      quantity != null &&
      lowStockThreshold != null &&
      quantity! <= lowStockThreshold!;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'sku': sku,
    'barcode': barcode,
    'category': category,
    'price': price,
    'quantity': quantity,
    'low_stock_threshold': lowStockThreshold,
  };

  factory LocalProduct.fromJson(Map<String, dynamic> json) => LocalProduct(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    sku: _text(json['sku']),
    barcode: _text(json['barcode']),
    category: _text(json['category']),
    price: _number(json['price']),
    quantity: _number(json['quantity']),
    lowStockThreshold: _number(json['low_stock_threshold']),
  );

  static String? _text(dynamic value) =>
      value == null || value.toString().isEmpty ? null : value.toString();

  static num? _number(dynamic value) =>
      value is num ? value : num.tryParse(value?.toString() ?? '');
}
