import 'package:flutter/material.dart';

import '../../../core/api/pos_api_service.dart';
import '../../../core/models/inventory_movement.dart';
import '../../../core/models/inventory_stock.dart';
import '../../../core/widgets/section_card.dart';
import '../../../shared/widgets/page_header.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({
    super.key,
    required this.apiService,
    required this.onConnect,
  });
  final PosApiService apiService;
  final VoidCallback onConnect;

  @override
  State<StockScreen> createState() => StockScreenState();
}

class StockScreenState extends State<StockScreen> {
  late Future<List<InventoryStock>> _stock;
  Future<List<InventoryMovement>>? _movements;
  bool _showMovements = false;

  @override
  void initState() {
    super.initState();
    _stock = widget.apiService.getInventoryStock();
  }

  void refresh() {
    setState(() {
      if (_showMovements) {
        _movements = widget.apiService.getInventoryMovements(
          forceRefresh: true,
        );
      } else {
        _stock = widget.apiService.getInventoryStock(forceRefresh: true);
      }
    });
  }

  void _refresh() => refresh();

  void _selectMovements(bool selected) {
    setState(() {
      _showMovements = selected;
      if (selected) _movements ??= widget.apiService.getInventoryMovements();
    });
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () async => _refresh(),
    child: CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(
          child: PageHeader(subtitle: 'Inventory and stock movements'),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Stock',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _refresh,
                      tooltip: 'Refresh stock',
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('Inventory'),
                      icon: Icon(Icons.inventory_2_outlined),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('Movements'),
                      icon: Icon(Icons.swap_vert),
                    ),
                  ],
                  selected: {_showMovements},
                  onSelectionChanged: (value) => _selectMovements(value.first),
                ),
                const SizedBox(height: 12),
                if (_showMovements)
                  FutureBuilder<List<InventoryMovement>>(
                    future: _movements,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const _Loading();
                      }
                      if (snapshot.hasError) {
                        return _StockError(
                          error: snapshot.error,
                          onRetry: _refresh,
                          onConnect: widget.onConnect,
                        );
                      }
                      final rows = snapshot.data ?? const <InventoryMovement>[];
                      if (rows.isEmpty) {
                        return const _Empty(
                          message: 'No stock movements returned.',
                        );
                      }
                      return Column(
                        children: [
                          for (final row in rows)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _MovementTile(movement: row),
                            ),
                        ],
                      );
                    },
                  )
                else
                  FutureBuilder<List<InventoryStock>>(
                    future: _stock,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const _Loading();
                      }
                      if (snapshot.hasError) {
                        return _StockError(
                          error: snapshot.error,
                          onRetry: _refresh,
                          onConnect: widget.onConnect,
                        );
                      }
                      final rows = snapshot.data ?? const <InventoryStock>[];
                      if (rows.isEmpty) {
                        return const _Empty(
                          message: 'No inventory records returned.',
                        );
                      }
                      return Column(
                        children: [
                          SectionCard(
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  color: Color(0xFF17834B),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Low stock is based on the API-provided threshold for each outlet.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          for (final row in rows)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _StockTile(stock: row),
                            ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _StockTile extends StatelessWidget {
  const _StockTile({required this.stock});
  final InventoryStock stock;
  @override
  Widget build(BuildContext context) => SectionCard(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: stock.isLowStock
                ? const Color(0xFFFFF2DD)
                : const Color(0xFFE8F4EC),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            stock.isLowStock
                ? Icons.warning_amber_rounded
                : Icons.inventory_2_outlined,
            color: const Color(0xFF17834B),
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stock.itemName,
                style: const TextStyle(fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Outlet ${stock.outletId ?? '—'} · Inventory ${stock.inventoryId}',
                style: const TextStyle(color: Color(0xFF69756E), fontSize: 12),
              ),
              if (stock.lowStockThreshold == null)
                const Text(
                  'Threshold not provided',
                  style: TextStyle(color: Color(0xFF69756E), fontSize: 12),
                ),
              if (stock.isLowStock)
                const Text(
                  'Low stock · at or below API threshold',
                  style: TextStyle(
                    color: Color(0xFFB54735),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _quantity(stock.quantity),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            if (stock.lowStockThreshold != null)
              Text(
                'Min ${_quantity(stock.lowStockThreshold!)}',
                style: const TextStyle(color: Color(0xFF69756E), fontSize: 11),
              ),
          ],
        ),
      ],
    ),
  );
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({required this.movement});
  final InventoryMovement movement;
  @override
  Widget build(BuildContext context) => SectionCard(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        const Icon(Icons.swap_vert, color: Color(0xFF17834B)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                movement.name?.isNotEmpty == true
                    ? movement.name!
                    : 'Inventory ${movement.inventoryId}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  movement.type,
                  if (movement.reason?.isNotEmpty == true) movement.reason!,
                  if (movement.outletId != null) 'Outlet ${movement.outletId}',
                ].join(' · '),
                style: const TextStyle(color: Color(0xFF69756E), fontSize: 12),
              ),
              if (movement.performedAt != null)
                Text(
                  movement.performedAt!.toLocal().toString(),
                  style: const TextStyle(
                    color: Color(0xFF69756E),
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Qty ${movement.quantity?.toString() ?? '—'}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              'After ${movement.stockAfter?.toString() ?? '—'}',
              style: const TextStyle(color: Color(0xFF69756E), fontSize: 11),
            ),
          ],
        ),
      ],
    ),
  );
}

String _quantity(num value) => value.toString();

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const SectionCard(
    child: Padding(
      padding: EdgeInsets.all(36),
      child: Center(child: CircularProgressIndicator()),
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => SectionCard(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Center(child: Text(message, textAlign: TextAlign.center)),
    ),
  );
}

class _StockError extends StatelessWidget {
  const _StockError({
    required this.error,
    required this.onRetry,
    required this.onConnect,
  });
  final Object? error;
  final VoidCallback onRetry;
  final VoidCallback onConnect;
  @override
  Widget build(BuildContext context) {
    final apiError = error is PosApiException ? error as PosApiException : null;
    return SectionCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              color: Color(0xFFB54735),
              size: 32,
            ),
            const SizedBox(height: 10),
            Text(
              apiError?.isUnauthorized == true
                  ? 'Authentication required'
                  : apiError?.statusCode == 403
                  ? 'Stock access denied'
                  : 'Stock is unavailable',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              apiError?.message ?? 'Could not load stock data.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF69756E)),
            ),
            const SizedBox(height: 12),
            if (apiError?.requiresToken == true)
              FilledButton.icon(
                onPressed: onConnect,
                icon: const Icon(Icons.key),
                label: const Text('Connect in Sales'),
              ),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
