class InventoryStock {
  const InventoryStock({
    required this.inventoryId,
    required this.itemName,
    required this.quantity,
    required this.lowStockThreshold,
    this.outletId,
    this.enabled,
  });

  final String inventoryId;
  final String itemName;
  final num quantity;
  final num? lowStockThreshold;
  final String? outletId;
  final bool? enabled;

  bool get isLowStock =>
      enabled != false &&
      lowStockThreshold != null &&
      quantity <= lowStockThreshold!;

  factory InventoryStock.fromJson(
    Map<String, dynamic> json, {
    required String itemName,
  }) => InventoryStock(
    inventoryId: json['inventory_id']?.toString() ?? '',
    itemName: itemName,
    quantity: _number(json['current_quantity']) ?? 0,
    lowStockThreshold: _number(json['low_stock_threshold']),
    outletId: json['outlet_id']?.toString(),
    enabled: json['is_enabled'] as bool?,
  );

  static num? _number(dynamic value) =>
      value is num ? value : num.tryParse(value?.toString() ?? '');
}
