class Sale {
  const Sale({
    required this.id,
    required this.outletId,
    required this.name,
    required this.showUuid,
    required this.totalPrice,
    required this.createdAt,
    required this.chargedAt,
    this.paymentType,
    this.orderOption,
    this.receiptStatus,
    this.refundedReceiptId,
  });

  final String id;
  final String outletId;
  final String? name;
  final String? showUuid;
  final num? totalPrice;
  final String? paymentType;
  final String? orderOption;
  final String? receiptStatus;
  final String? refundedReceiptId;
  final DateTime? createdAt;
  final DateTime? chargedAt;

  factory Sale.fromJson(Map<String, dynamic> json) => Sale(
    id: json['id']?.toString() ?? '',
    outletId: json['outlet_id']?.toString() ?? '',
    name: json['name']?.toString() ?? json['open_order_name']?.toString(),
    showUuid: json['show_uuid']?.toString(),
    totalPrice: _number(json['payable_amount'] ?? json['total_price']),
    paymentType: json['payment_type']?.toString(),
    orderOption: json['order_option']?.toString(),
    receiptStatus: json['receipt_status']?.toString(),
    refundedReceiptId: json['refunded_receipt_id']?.toString(),
    createdAt: _date(json['created_at']),
    chargedAt: _date(json['charged_at'] ?? json['order_end_time']),
  );

  static num? _number(dynamic value) =>
      value is num ? value : num.tryParse('$value');

  static DateTime? _date(dynamic value) =>
      value is String ? DateTime.tryParse(value) : null;
}
