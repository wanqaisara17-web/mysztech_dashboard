import 'package:flutter/material.dart';

import '../../../core/api/pos_api_service.dart';
import '../../../core/models/item.dart';
import '../../../core/widgets/section_card.dart';
import '../../../shared/widgets/page_header.dart';
import 'local_label_screen.dart';

class ItemsScreen extends StatefulWidget {
  const ItemsScreen({
    super.key,
    required this.apiService,
    required this.onConnect,
  });

  final PosApiService apiService;
  final VoidCallback onConnect;

  @override
  State<ItemsScreen> createState() => ItemsScreenState();
}

class ItemsScreenState extends State<ItemsScreen> {
  late Future<List<PosItem>> _items;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _items = widget.apiService.getItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void refresh() => setState(() {
    _items = widget.apiService.getItems(forceRefresh: true);
  });

  void _refresh() => refresh();

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () async => _refresh(),
    child: CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(
          child: PageHeader(subtitle: 'Browse your POS catalog'),
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
                      'Items',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _refresh,
                      tooltip: 'Refresh items',
                      icon: const Icon(Icons.refresh),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const LocalLabelScreen(),
                        ),
                      ),
                      tooltip: 'Create local label',
                      icon: const Icon(Icons.local_offer_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchController,
                  onChanged: (value) =>
                      setState(() => _query = value.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search name, SKU, or barcode',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.clear),
                          ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<PosItem>>(
                  future: _items,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const _ItemsLoading();
                    }
                    if (snapshot.hasError) {
                      return _ItemsError(
                        error: snapshot.error,
                        onRetry: _refresh,
                        onConnect: widget.onConnect,
                      );
                    }
                    final items = (snapshot.data ?? const <PosItem>[])
                        .where((item) => _matches(item, _query))
                        .toList(growable: false);
                    if (items.isEmpty) {
                      return _ItemsEmpty(hasSearch: _query.isNotEmpty);
                    }
                    return Column(
                      children: [
                        for (final item in items)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ItemTile(
                              item: item,
                              onTap: () => _openItem(item),
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

  bool _matches(PosItem item, String query) =>
      query.isEmpty ||
      item.name.toLowerCase().contains(query) ||
      (item.sku?.toLowerCase().contains(query) ?? false) ||
      (item.barcode?.toLowerCase().contains(query) ?? false);

  Future<void> _openItem(PosItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ItemDetailScreen(
          apiService: widget.apiService,
          fallback: item,
          onConnect: widget.onConnect,
        ),
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item, required this.onTap});
  final PosItem item;
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
              color: const Color(0xFFE8F4EC),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.category_outlined,
              color: Color(0xFF17834B),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Text(
                  _itemSubtitle(item),
                  style: const TextStyle(
                    color: Color(0xFF69756E),
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            item.price == null ? '—' : item.price.toString(),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );
}

String _itemSubtitle(PosItem item) => [
  if (item.sku?.isNotEmpty == true) 'SKU ${item.sku}',
  if (item.barcode?.isNotEmpty == true) 'Barcode ${item.barcode}',
  if (item.categoryName?.isNotEmpty == true) item.categoryName!,
  if (item.categoryName == null && item.categoryId != null)
    'Category ${item.categoryId}',
].join(' · ');

class _ItemsLoading extends StatelessWidget {
  const _ItemsLoading();
  @override
  Widget build(BuildContext context) => const SectionCard(
    child: Padding(
      padding: EdgeInsets.all(36),
      child: Center(child: CircularProgressIndicator()),
    ),
  );
}

class _ItemsEmpty extends StatelessWidget {
  const _ItemsEmpty({required this.hasSearch});
  final bool hasSearch;
  @override
  Widget build(BuildContext context) => SectionCard(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: Text(
          hasSearch
              ? 'No items match this search.'
              : 'No items returned by the POS.',
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}

class _ItemsError extends StatelessWidget {
  const _ItemsError({
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
                  ? 'Items access denied'
                  : 'Items are unavailable',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              apiError?.message ?? 'Could not load the item catalog.',
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

class _ItemDetailScreen extends StatefulWidget {
  const _ItemDetailScreen({
    required this.apiService,
    required this.fallback,
    required this.onConnect,
  });
  final PosApiService apiService;
  final PosItem fallback;
  final VoidCallback onConnect;
  @override
  State<_ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<_ItemDetailScreen> {
  late Future<PosItem> _item;
  @override
  void initState() {
    super.initState();
    _item = widget.apiService.getItem(widget.fallback.id);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Item details')),
    body: FutureBuilder<PosItem>(
      future: _item,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ItemsError(
            error: snapshot.error,
            onRetry: () => setState(
              () => _item = widget.apiService.getItem(widget.fallback.id),
            ),
            onConnect: widget.onConnect,
          );
        }
        final item = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  _DetailLine(label: 'SKU', value: item.sku),
                  _DetailLine(label: 'Barcode', value: item.barcode),
                  _DetailLine(label: 'Price', value: item.price?.toString()),
                  _DetailLine(
                    label: 'Category',
                    value: item.categoryName ?? item.categoryId,
                  ),
                  _DetailLine(label: 'Unit', value: item.unit),
                  _DetailLine(label: 'Description', value: item.description),
                ],
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => LocalLabelScreen(item: item),
                ),
              ),
              icon: const Icon(Icons.local_offer_outlined),
              label: const Text('Create local label'),
            ),
          ],
        );
      },
    ),
  );
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});
  final String label;
  final String? value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 11),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: const TextStyle(color: Color(0xFF69756E))),
        ),
        Expanded(
          child: Text(value?.isNotEmpty == true ? value! : 'Not provided'),
        ),
      ],
    ),
  );
}
