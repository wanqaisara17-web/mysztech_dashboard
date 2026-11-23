import 'sale.dart';

class SalesPage {
  const SalesPage({required this.sales, required this.total});

  final List<Sale> sales;
  final int? total;

  factory SalesPage.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final paginator = json['paginator'];
    if (data is! List || paginator is! Map<String, dynamic>) {
      throw const FormatException(
        'Sales response is missing data or paginator.',
      );
    }
    final rawTotal = paginator['total'];
    return SalesPage(
      sales: data
          .whereType<Map<String, dynamic>>()
          .map(Sale.fromJson)
          .toList(growable: false),
      total: rawTotal is int ? rawTotal : int.tryParse('$rawTotal'),
    );
  }
}
