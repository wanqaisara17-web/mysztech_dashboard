import 'sale.dart';

class SalesPage {
  const SalesPage({
    required this.sales,
    required this.total,
    this.page,
    this.count,
    this.lastPage,
    this.perPage,
  });

  final List<Sale> sales;
  final int? total;
  final int? page;
  final int? count;
  final int? lastPage;
  final int? perPage;

  factory SalesPage.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final paginator = json['paginator'];
    if (data is! List || paginator is! Map<String, dynamic>) {
      throw const FormatException(
        'Sales response is missing data or paginator.',
      );
    }
    final rawTotal = paginator['total'];
    int? asInt(dynamic value) => value is int ? value : int.tryParse('$value');
    return SalesPage(
      sales: data
          .whereType<Map<String, dynamic>>()
          .map(Sale.fromJson)
          .toList(growable: false),
      total: rawTotal is int ? rawTotal : int.tryParse('$rawTotal'),
      count: asInt(paginator['count']),
      page: asInt(paginator['page']) ?? asInt(paginator['currentPage']),
      lastPage: asInt(paginator['lastPage']),
      perPage: asInt(paginator['perPage']),
    );
  }
}
