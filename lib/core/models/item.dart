class PosItem {
  const PosItem({
    required this.id,
    required this.name,
    this.sku,
    this.barcode,
    this.price,
    this.categoryId,
    this.categoryName,
    this.inventoryId,
    this.description,
    this.unit,
    this.trackingEnabled = false,
  });

  final String id;
  final String name;
  final String? sku;
  final String? barcode;
  final num? price;
  final String? categoryId;
  final String? categoryName;
  final String? inventoryId;
  final String? description;
  final String? unit;
  final bool trackingEnabled;

  factory PosItem.fromJson(Map<String, dynamic> json, {String? categoryName}) =>
      PosItem(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Unnamed item',
        sku: _nullableString(json['sku']),
        barcode: _nullableString(json['barcode']),
        price: _number(json['price']),
        categoryId: _nullableString(json['category_id']),
        categoryName: categoryName,
        inventoryId: _nullableString(json['inventory_id']),
        description: _nullableString(json['description']),
        unit: _nullableString(json['unit']),
        trackingEnabled: json['tracking_enabled'] == true,
      );

  PosItem withCategory(String? name) => PosItem(
    id: id,
    name: this.name,
    sku: sku,
    barcode: barcode,
    price: price,
    categoryId: categoryId,
    categoryName: name,
    inventoryId: inventoryId,
    description: description,
    unit: unit,
    trackingEnabled: trackingEnabled,
  );

  static String? _nullableString(dynamic value) =>
      value == null || value.toString().isEmpty ? null : value.toString();

  static num? _number(dynamic value) =>
      value is num ? value : num.tryParse(value?.toString() ?? '');
}
