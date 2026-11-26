import 'sale.dart';

class SalesHistory {
  const SalesHistory({
    required this.sales,
    required this.total,
    required this.isComplete,
    this.error,
  });

  final List<Sale> sales;
  final int? total;
  final bool isComplete;
  final Object? error;
}
