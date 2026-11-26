import 'sales_history.dart';

Map<DateTime, int>? dailyReceiptCounts(
  SalesHistory history, {
  required DateTime through,
  int days = 7,
}) {
  if (!history.isComplete || days < 1) return null;
  final today = DateTime(through.year, through.month, through.day);
  final counts = <DateTime, int>{
    for (var offset = days - 1; offset >= 0; offset--)
      today.subtract(Duration(days: offset)): 0,
  };
  for (final receipt in history.sales) {
    final createdAt = receipt.createdAt?.toLocal();
    if (createdAt == null) return null;
    final day = DateTime(createdAt.year, createdAt.month, createdAt.day);
    if (counts.containsKey(day)) counts[day] = counts[day]! + 1;
  }
  return counts;
}
