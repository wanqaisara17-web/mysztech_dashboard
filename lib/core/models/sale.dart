class Sale {
  const Sale({
    required this.id,
    required this.outletId,
    required this.name,
    required this.totalPrice,
    required this.createdAt,
    required this.chargedAt,
  });

  final String id;
  final String outletId;
  final String? name;
  final num? totalPrice;
  final DateTime? createdAt;
  final DateTime? chargedAt;

  factory Sale.fromJson(Map<String, dynamic> json) => Sale(
    id: json['id']?.toString() ?? '',
    outletId: json['outlet_id']?.toString() ?? '',
    name: json['name']?.toString() ?? json['open_order_name']?.toString(),
    totalPrice: _number(json['total_price'] ?? json['payable_amount']),
    createdAt: _date(json['created_at']),
    chargedAt: _date(json['charged_at'] ?? json['order_end_time']),
  );

  static num? _number(dynamic value) =>
      value is num ? value : num.tryParse('$value');

  static DateTime? _date(dynamic value) =>
      value is String ? DateTime.tryParse(value) : null;
}
