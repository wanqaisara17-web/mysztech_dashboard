import 'package:flutter/material.dart';

import '../../../core/api/pos_api_service.dart';
import '../../../core/models/sales_page.dart';
import '../../../core/models/sales_history.dart';
import '../../../core/models/receipt_activity.dart';
import '../../../core/models/inventory_stock.dart';
import '../../../core/widgets/section_card.dart';
import '../../../shared/widgets/page_header.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.apiService,
    required this.onOpenSales,
    required this.onOpenLowStock,
    this.selectedOutletId,
    this.selectedOutletName,
  });

  final PosApiService apiService;
  final VoidCallback onOpenSales;
  final VoidCallback onOpenLowStock;
  final String? selectedOutletId;
  final String? selectedOutletName;

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  late Future<SalesPage> _sales;
  late Future<SalesHistory> _history;
  late Future<List<InventoryStock>> _stock;

  @override
  void initState() {
    super.initState();
    _sales = widget.apiService.getSales();
    _history = widget.apiService.getCompleteSalesHistory(
      outletId: widget.selectedOutletId,
    );
    _stock = widget.apiService.getInventoryStock();
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedOutletId != null &&
        oldWidget.selectedOutletId != widget.selectedOutletId) {
      refreshSales();
    }
  }

  void _retry() {
    refreshSales();
  }

  void refreshSales({bool forceRefresh = true}) {
    setState(() {
      _sales = widget.apiService.getSales(forceRefresh: forceRefresh);
      _history = widget.apiService.getCompleteSalesHistory(
        outletId: widget.selectedOutletId,
      );
      _stock = widget.apiService.getInventoryStock(forceRefresh: forceRefresh);
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: RefreshIndicator(
          onRefresh: () async => _retry(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: PageHeader(
                  subtitle: widget.selectedOutletName?.isNotEmpty == true
                      ? 'Overview for ${widget.selectedOutletName}'
                      : 'Your business at a glance',
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                sliver: SliverList.list(
                  children: [
                    Row(
                      children: [
                        Text(
                          'Overview',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          style: const ButtonStyle(
                            minimumSize: WidgetStatePropertyAll(Size.zero),
                            padding: WidgetStatePropertyAll(
                              EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                            ),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: widget.onOpenSales,
                          icon: const Icon(Icons.arrow_forward, size: 17),
                          label: const Text('Sales'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    FutureBuilder<SalesPage>(
                      future: _sales,
                      builder: (context, snapshot) {
                        final isLoading =
                            snapshot.connectionState == ConnectionState.waiting;
                        final count = isLoading ? null : snapshot.data?.total;
                        return _SummaryCard(
                          label: 'Sales records',
                          value: snapshot.hasError || count == null
                              ? '—'
                              : '$count',
                          detail: snapshot.hasError
                              ? 'Sales data unavailable'
                              : isLoading
                              ? 'Loading from production API…'
                              : 'Total reported by the sales list',
                          icon: Icons.receipt_long_outlined,
                          color: const Color(0xFFE7F4EB),
                          onTap: widget.onOpenSales,
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    const _SummaryCard(
                      label: 'Sales amount',
                      value: '—',
                      detail: 'Not available in the confirmed dashboard data',
                      icon: Icons.payments_outlined,
                      color: Color(0xFFEAF0FB),
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<List<InventoryStock>>(
                      future: _stock,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return _SummaryCard(
                            label: 'Low-stock records',
                            value: '…',
                            detail: 'Loading inventory from production API',
                            icon: Icons.inventory_2_outlined,
                            color: Color(0xFFFFF2DD),
                            onTap: widget.onOpenLowStock,
                          );
                        }
                        if (snapshot.hasError) {
                          return _SummaryCard(
                            label: 'Low-stock records',
                            value: '—',
                            detail: 'Stock data unavailable',
                            icon: Icons.inventory_2_outlined,
                            color: Color(0xFFFFF2DD),
                            onTap: widget.onOpenLowStock,
                          );
                        }
                        final rows = snapshot.data ?? const <InventoryStock>[];
                        final thresholdRows = rows
                            .where((row) => row.lowStockThreshold != null)
                            .toList();
                        final lowStockCount = thresholdRows
                            .where((row) => row.isLowStock)
                            .length;
                        return _SummaryCard(
                          label: 'Low-stock records',
                          value: rows.isNotEmpty && thresholdRows.isEmpty
                              ? '—'
                              : '$lowStockCount',
                          detail: rows.isEmpty
                              ? 'No inventory records returned'
                              : thresholdRows.isEmpty
                              ? 'API did not provide low-stock thresholds'
                              : 'At or below API-provided threshold',
                          icon: Icons.inventory_2_outlined,
                          color: const Color(0xFFFFF2DD),
                          onTap: widget.onOpenLowStock,
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    FutureBuilder<SalesHistory>(
                      future: _history,
                      builder: (context, snapshot) => _ReceiptActivityCard(
                        history:
                            snapshot.connectionState == ConnectionState.waiting
                            ? null
                            : snapshot.data,
                        loading:
                            snapshot.connectionState == ConnectionState.waiting,
                        error: snapshot.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        child: Align(
          alignment: Alignment.centerRight,
          child: FloatingActionButton.extended(
            heroTag: 'mysztech_ai_preview',
            tooltip: 'Preview the upcoming Mysztech AI assistant',
            backgroundColor: const Color(0xFF17834B),
            foregroundColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Mysztech AI \u2014 Coming Soon!'),
                ),
              );
            },
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Mysztech AI'),
          ),
        ),
      ),
    ],
  );
}

class _ReceiptActivityCard extends StatelessWidget {
  const _ReceiptActivityCard({this.history, this.loading = false, this.error});
  final SalesHistory? history;
  final bool loading;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    final complete = history?.isComplete == true;
    final counts = history == null
        ? null
        : dailyReceiptCounts(history!, through: DateTime.now());
    final days = counts?.keys.toList() ?? const <DateTime>[];
    final maxCount = counts?.values.fold<int>(0, (a, b) => a > b ? a : b) ?? 0;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_outlined, color: Color(0xFF17834B)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Receipt activity',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            error != null || history == null
                ? 'Receipt activity is unavailable.'
                : complete && counts == null
                ? 'Receipt dates are missing; activity cannot be charted.'
                : complete
                ? 'Daily receipt records by created date · ${history!.sales.length} loaded'
                : 'Incomplete receipt data · chart hidden until all pages load',
            style: const TextStyle(color: Color(0xFF69756E), height: 1.4),
          ),
          if (complete && counts != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 112,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: days.map((day) {
                  final count = counts[day]!;
                  final barHeight = maxCount == 0 ? 2.0 : 64 * count / maxCount;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '$count',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF69756E),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: barHeight,
                            decoration: BoxDecoration(
                              color: const Color(0xFF17834B),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${day.month}/${day.day}',
                            style: const TextStyle(
                              fontSize: 9,
                              color: Color(0xFF69756E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Receipt counts only. This is not revenue or a count of completed sales.',
              style: TextStyle(fontSize: 11, color: Color(0xFF69756E)),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: SectionCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF17834B)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF69756E),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: const TextStyle(
                    color: Color(0xFF87918B),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
