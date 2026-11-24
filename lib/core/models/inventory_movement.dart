class InventoryMovement {
  const InventoryMovement({
    required this.id,
    required this.inventoryId,
    required this.type,
    required this.quantity,
    required this.stockAfter,
    this.name,
    this.outletId,
    this.reason,
    this.performedAt,
  });

  final String id;
  final String inventoryId;
  final String type;
  final num? quantity;
  final num? stockAfter;
  final String? name;
  final String? outletId;
  final String? reason;
  final DateTime? performedAt;

  factory InventoryMovement.fromJson(Map<String, dynamic> json) =>
      InventoryMovement(
        id: json['id']?.toString() ?? '',
        inventoryId: json['inventory_id']?.toString() ?? '',
        type: json['type']?.toString() ?? 'Movement',
        quantity: _number(json['quantity']),
        stockAfter: _number(json['stock_after']),
        name: json['name']?.toString(),
        outletId: json['outlet_id']?.toString(),
        reason: json['reason']?.toString(),
        performedAt: json['performed_at'] is String
            ? DateTime.tryParse(json['performed_at'] as String)
            : null,
      );

  InventoryMovement withName(String? value) => InventoryMovement(
    id: id,
    inventoryId: inventoryId,
    type: type,
    quantity: quantity,
    stockAfter: stockAfter,
    name: value,
    outletId: outletId,
    reason: reason,
    performedAt: performedAt,
  );

  static num? _number(dynamic value) =>
      value is num ? value : num.tryParse(value?.toString() ?? '');
}
