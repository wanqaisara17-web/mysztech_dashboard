import 'package:flutter/material.dart';

import '../../../core/api/pos_api_service.dart';
import '../../../core/local/local_workspace.dart';
import '../../../core/models/inventory_movement.dart';
import '../../../core/models/inventory_stock.dart';
import '../../../core/models/local_product.dart';
import '../../../core/models/outlet.dart';
import '../../../core/widgets/section_card.dart';
import '../../../shared/widgets/page_header.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({
    super.key,
    required this.apiService,
    required this.onConnect,
    required this.workspace,
    required this.onOpenLocalItems,
    this.outletNames = const {},
    this.selectedOutletId,
  });
  final PosApiService apiService;
  final VoidCallback onConnect;
  final LocalWorkspace workspace;
  final VoidCallback onOpenLocalItems;
  final Map<String, String> outletNames;
  final String? selectedOutletId;

  @override
  State<StockScreen> createState() => StockScreenState();
}

class StockScreenState extends State<StockScreen> {
  late Future<List<InventoryStock>> _stock;
  Future<List<InventoryMovement>>? _movements;
  String _view = 'inventory';
  String _query = '';
  bool _lowOnly = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void showLowStock() {
    setState(() {
      _view = 'inventory';
      _lowOnly = true;
      _query = '';
      _searchController.clear();
    });
  }

  @override
  void initState() {
    super.initState();
    _stock = widget.apiService.getInventoryStock();
  }

  void refresh() {
    setState(() {
      if (_view == 'movements') {
        _movements = widget.apiService.getInventoryMovements(
          forceRefresh: true,
        );
      } else if (_view == 'inventory') {
        _stock = widget.apiService.getInventoryStock(forceRefresh: true);
      }
    });
  }

  void _refresh() => refresh();

  @override
  void didUpdateWidget(covariant StockScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedOutletId != null &&
        oldWidget.selectedOutletId != widget.selectedOutletId) {
      _stock = widget.apiService.getInventoryStock(forceRefresh: true);
      _movements = widget.apiService.getInventoryMovements(forceRefresh: true);
    }
  }

  void _selectView(String view) {
    setState(() {
      _view = view;
      if (view == 'movements') {
        _movements ??= widget.apiService.getInventoryMovements();
      }
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
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 480) {
                      return Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _StockViewChip(
                            label: 'Inventory',
                            icon: Icons.inventory_2_outlined,
                            value: 'inventory',
                            selected: _view == 'inventory',
                            onSelected: _selectView,
                          ),
                          _StockViewChip(
                            label: 'Movements',
                            icon: Icons.swap_vert,
                            value: 'movements',
                            selected: _view == 'movements',
                            onSelected: _selectView,
                          ),
                          _StockViewChip(
                            label: 'On-device',
                            icon: Icons.phone_android,
                            value: 'local',
                            selected: _view == 'local',
                            onSelected: _selectView,
                          ),
                        ],
                      );
                    }
                    return SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'inventory',
                          label: Text('Inventory'),
                          icon: Icon(Icons.inventory_2_outlined),
                        ),
                        ButtonSegment(
                          value: 'movements',
                          label: Text('Movements'),
                          icon: Icon(Icons.swap_vert),
                        ),
                        ButtonSegment(
                          value: 'local',
                          label: Text('On-device'),
                          icon: Icon(Icons.phone_android),
                        ),
                      ],
                      selected: {_view},
                      onSelectionChanged: (value) => _selectView(value.first),
                    );
                  },
                ),
                const SizedBox(height: 12),
                if (_view == 'inventory') ...[
                  TextField(
                    controller: _searchController,
                    onChanged: (value) =>
                        setState(() => _query = value.trim().toLowerCase()),
                    decoration: const InputDecoration(
                      hintText: 'Search inventory by product name',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('All Stock'),
                        selected: !_lowOnly,
                        onSelected: (_) => setState(() => _lowOnly = false),
                      ),
                      ChoiceChip(
                        label: const Text('Low Stock'),
                        selected: _lowOnly,
                        onSelected: (_) => setState(() => _lowOnly = true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                if (_view == 'local')
                  AnimatedBuilder(
                    animation: widget.workspace,
                    builder: (context, _) {
                      if (!widget.workspace.isLoaded) return const _Loading();
                      final products = widget.workspace.products
                          .where((product) => product.quantity != null)
                          .toList(growable: false);
                      if (products.isEmpty) {
                        return _LocalStockEmpty(
                          onOpenItems: widget.onOpenLocalItems,
                        );
                      }
                      return Column(
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'LOCAL ONLY · On-device counts do not sync to POS',
                                style: TextStyle(
                                  color: Color(0xFF69756E),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          for (final product in products)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _LocalStockTile(product: product),
                            ),
                        ],
                      );
                    },
                  )
                else if (_view == 'movements')
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
                              child: _MovementTile(
                                movement: row,
                                outletNames: widget.outletNames,
                              ),
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
                      final rows = (snapshot.data ?? const <InventoryStock>[])
                          .where(
                            (row) =>
                                row.itemName.toLowerCase().contains(_query),
                          )
                          .where((row) => !_lowOnly || row.isLowStock)
                          .toList(growable: false);
                      if (rows.isEmpty) {
                        return _Empty(
                          message: _query.isNotEmpty
                              ? 'No inventory names match this search.'
                              : _lowOnly
                              ? 'No low-stock inventory records returned.'
                              : 'No inventory records returned.',
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
                              child: _StockTile(
                                stock: row,
                                outletNames: widget.outletNames,
                                onTap: () => _showStockDetails(
                                  context,
                                  row,
                                  widget.outletNames,
                                ),
                              ),
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

void _showStockDetails(
  BuildContext context,
  InventoryStock stock,
  Map<String, String> outletNames,
) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(stock.itemName),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Inventory ID: ${stock.inventoryId}'),
          Text('Outlet: ${outletLabel(outletNames, stock.outletId)}'),
          Text('Available: ${stock.quantity}'),
          Text(
            'Low-stock threshold: ${stock.lowStockThreshold?.toString() ?? 'Not provided'}',
          ),
          Text('Enabled: ${stock.enabled?.toString() ?? 'Not provided'}'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

class _StockViewChip extends StatelessWidget {
  const _StockViewChip({
    required this.label,
    required this.icon,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final String value;
  final bool selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    avatar: Icon(icon, size: 18),
    label: Text(label),
    selected: selected,
    onSelected: (_) => onSelected(value),
  );
}

class _StockTile extends StatelessWidget {
  const _StockTile({
    required this.stock,
    required this.outletNames,
    required this.onTap,
  });
  final InventoryStock stock;
  final Map<String, String> outletNames;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: SectionCard(
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
                  '${outletLabel(outletNames, stock.outletId)} · Inventory ${stock.inventoryId}',
                  style: const TextStyle(
                    color: Color(0xFF69756E),
                    fontSize: 12,
                  ),
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
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              if (stock.lowStockThreshold != null)
                Text(
                  'Min ${_quantity(stock.lowStockThreshold!)}',
                  style: const TextStyle(
                    color: Color(0xFF69756E),
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({required this.movement, required this.outletNames});
  final InventoryMovement movement;
  final Map<String, String> outletNames;
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
                  if (movement.outletId != null)
                    outletLabel(outletNames, movement.outletId),
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

class _LocalStockTile extends StatelessWidget {
  const _LocalStockTile({required this.product});
  final LocalProduct product;

  @override
  Widget build(BuildContext context) => SectionCard(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        Icon(
          product.isLowStock
              ? Icons.warning_amber_rounded
              : Icons.inventory_2_outlined,
          color: const Color(0xFF17834B),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                'On-device count${product.isLowStock ? ' · Low local stock' : ''}',
                style: TextStyle(
                  color: product.isLowStock
                      ? const Color(0xFFB54735)
                      : const Color(0xFF69756E),
                  fontSize: 12,
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
              _quantity(product.quantity!),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            if (product.lowStockThreshold != null)
              Text(
                'Min ${_quantity(product.lowStockThreshold!)}',
                style: const TextStyle(color: Color(0xFF69756E), fontSize: 11),
              ),
          ],
        ),
      ],
    ),
  );
}

class _LocalStockEmpty extends StatelessWidget {
  const _LocalStockEmpty({required this.onOpenItems});
  final VoidCallback onOpenItems;
  @override
  Widget build(BuildContext context) => SectionCard(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          const Text(
            'No local stock notes yet. Add an on-device item with an on-hand count to track it here.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onOpenItems,
            icon: const Icon(Icons.category_outlined),
            label: const Text('Open local catalog'),
          ),
        ],
      ),
    ),
  );
}

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
    final requiresSignIn =
        apiError?.requiresToken == true || apiError?.isUnauthorized == true;
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
            if (requiresSignIn)
              FilledButton.icon(
                onPressed: onConnect,
                icon: const Icon(Icons.login),
                label: const Text('Sign in again'),
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
