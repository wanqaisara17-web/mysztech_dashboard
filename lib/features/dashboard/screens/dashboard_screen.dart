import 'package:flutter/material.dart';

import '../../../core/api/pos_api_service.dart';
import '../../../core/models/sales_page.dart';
import '../../../core/models/inventory_stock.dart';
import '../../../core/widgets/section_card.dart';
import '../../../shared/widgets/page_header.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.apiService,
    required this.onOpenSales,
  });

  final PosApiService apiService;
  final VoidCallback onOpenSales;

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  late Future<SalesPage> _sales;
  late Future<List<InventoryStock>> _stock;

  @override
  void initState() {
    super.initState();
    _sales = widget.apiService.getSales();
    _stock = widget.apiService.getInventoryStock();
  }

  void _retry() {
    refreshSales();
  }

  void refreshSales({bool forceRefresh = true}) {
    setState(() {
      _sales = widget.apiService.getSales(forceRefresh: forceRefresh);
      _stock = widget.apiService.getInventoryStock(forceRefresh: forceRefresh);
    });
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () async => _retry(),
    child: CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(
          child: PageHeader(subtitle: 'Your business at a glance'),
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
                  final count = snapshot.data?.total;
                  return _SummaryCard(
                    label: 'Sales records',
                    value: snapshot.hasError || count == null ? '—' : '$count',
                    detail: snapshot.hasError
                        ? 'Sales data unavailable'
                        : snapshot.connectionState == ConnectionState.waiting
                        ? 'Loading from production API…'
                        : 'Total reported by the sales list',
                    icon: Icons.receipt_long_outlined,
                    color: const Color(0xFFE7F4EB),
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
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const _SummaryCard(
                      label: 'Low-stock records',
                      value: '…',
                      detail: 'Loading inventory from production API',
                      icon: Icons.inventory_2_outlined,
                      color: Color(0xFFFFF2DD),
                    );
                  }
                  if (snapshot.hasError) {
                    return const _SummaryCard(
                      label: 'Low-stock records',
                      value: '—',
                      detail: 'Stock data unavailable',
                      icon: Icons.inventory_2_outlined,
                      color: Color(0xFFFFF2DD),
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
                  );
                },
              ),
              const SizedBox(height: 24),
              SectionCard(
                child: Row(
                  children: [
                    const Icon(
                      Icons.insights_outlined,
                      color: Color(0xFF17834B),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sales activity',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'A sales chart will appear when a confirmed trend data source is available.',
                            style: TextStyle(
                              color: Color(0xFF69756E),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => SectionCard(
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
                style: const TextStyle(color: Color(0xFF69756E), fontSize: 13),
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
                style: const TextStyle(color: Color(0xFF87918B), fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
