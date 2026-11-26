import 'package:flutter/material.dart';

import '../../../core/api/pos_api_service.dart';
import '../../../core/models/sale.dart';
import '../../../core/widgets/section_card.dart';
import '../../../shared/widgets/page_header.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({
    super.key,
    required this.apiService,
    this.onReauthenticate,
    this.selectedOutletId,
    this.outletNames = const {},
  });

  final PosApiService apiService;
  final VoidCallback? onReauthenticate;
  final String? selectedOutletId;
  final Map<String, String> outletNames;

  @override
  State<SalesScreen> createState() => SalesScreenState();
}

class _PageRetry extends StatelessWidget {
  const _PageRetry({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => SectionCard(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          const Text(
            'More receipts could not be loaded. Loaded records remain available.',
          ),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry loading more'),
          ),
        ],
      ),
    ),
  );
}

class _EndOfSales extends StatelessWidget {
  const _EndOfSales({
    this.message = 'All available receipt records are loaded',
  });
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: 12),
    child: Center(
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFF69756E), fontSize: 12),
      ),
    ),
  );
}

class SalesScreenState extends State<SalesScreen> {
  final _scrollController = ScrollController();
  final List<Sale> _sales = [];
  final Set<String> _requestedPages = {};
  int? _total;
  int? _lastPage;
  int _page = 0;
  int _generation = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _paginationUnavailable = false;
  Object? _error;

  @override
  void didUpdateWidget(covariant SalesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.apiService != widget.apiService ||
        (oldWidget.selectedOutletId != null &&
            oldWidget.selectedOutletId != widget.selectedOutletId)) {
      loadFirstPage();
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadNext);
    loadFirstPage();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void refreshForOutlet() => loadFirstPage();

  void loadFirstPage() {
    final generation = ++_generation;
    setState(() {
      _sales.clear();
      _requestedPages.clear();
      _page = 0;
      _total = null;
      _lastPage = null;
      _paginationUnavailable = false;
      _loading = true;
      _loadingMore = false;
      _error = null;
    });
    _loadPage(1, generation, forceRefresh: true);
  }

  void _retry() {
    if (_sales.isEmpty) {
      loadFirstPage();
    } else if (_error != null) {
      final next = _page + 1;
      _loadPage(next, _generation, forceRefresh: true);
    }
  }

  void _maybeLoadNext() {
    if (!_scrollController.hasClients ||
        _loading ||
        _loadingMore ||
        _error != null) {
      return;
    }
    if (_scrollController.position.extentAfter < 320) _loadNextPage();
  }

  void _loadNextPage() {
    final next = _page + 1;
    if (_paginationUnavailable ||
        (_lastPage != null && next > _lastPage!) ||
        _requestedPages.contains('$_generation:$next')) {
      return;
    }
    _loadPage(next, _generation);
  }

  Future<void> _loadPage(
    int page,
    int generation, {
    bool forceRefresh = false,
  }) async {
    final requestKey = '$generation:$page';
    if (!_requestedPages.add(requestKey)) {
      return;
    }
    setState(() {
      if (page == 1) {
        _loading = true;
      } else {
        _loadingMore = true;
      }
      _error = null;
    });
    try {
      final result = await widget.apiService.getSales(
        page: page,
        outletId: widget.selectedOutletId,
        forceRefresh: forceRefresh,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        final before = _sales.length;
        final existing = _sales
            .map((sale) => sale.id.isNotEmpty ? sale.id : sale.showUuid ?? '')
            .where((id) => id.isNotEmpty)
            .toSet();
        for (final sale in result.sales) {
          final key = sale.id.isNotEmpty ? sale.id : sale.showUuid ?? '';
          if (key.isEmpty || existing.add(key)) _sales.add(sale);
        }
        _page = page;
        _total = result.total;
        _lastPage = result.lastPage;
        if (page > 1 &&
            _sales.length == before &&
            (_total == null || _sales.length < _total!)) {
          _paginationUnavailable = true;
        }
      });
    } catch (error) {
      if (mounted && generation == _generation) setState(() => _error = error);
    } finally {
      _requestedPages.remove(requestKey);
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () async => loadFirstPage(),
    child: CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(
          child: PageHeader(subtitle: 'Track sales from your POS'),
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
                      'Sales',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: loadFirstPage,
                      tooltip: 'Refresh sales',
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_loading && _sales.isEmpty)
                  const _LoadingState()
                else if (_error != null && _sales.isEmpty)
                  _ErrorState(
                    error: _error,
                    onRetry: _retry,
                    onReauthenticate: widget.onReauthenticate,
                  )
                else if (_sales.isEmpty)
                  _EmptyState(total: _total)
                else ...[
                  _CountBanner(total: _total, showing: _sales.length),
                  const SizedBox(height: 12),
                  ..._sales.map(
                    (sale) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SaleTile(
                        sale: sale,
                        outletName: widget.outletNames[sale.outletId],
                      ),
                    ),
                  ),
                  if (_loadingMore)
                    const Padding(
                      padding: EdgeInsets.all(18),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null)
                    _PageRetry(onRetry: _retry)
                  else if (_paginationUnavailable)
                    const _EndOfSales(
                      message: 'The API did not return additional records for this page.',
                    )
                  else if (_lastPage != null && _page >= _lastPage!)
                    const _EndOfSales()
                  else if (_total != null && _sales.length >= _total!)
                    const _EndOfSales()
                  else
                    TextButton.icon(
                      onPressed: _loadNextPage,
                      icon: const Icon(Icons.expand_more),
                      label: const Text('Load more'),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) => const SectionCard(
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: 38),
      child: Center(child: CircularProgressIndicator()),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.total});

  final int? total;

  @override
  Widget build(BuildContext context) => SectionCard(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 18),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFE8F4EC),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 30,
              color: Color(0xFF17834B),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No sales records yet',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          Text(
            total == 0
                ? 'The API reports 0 total sales. New records will appear here when available.'
                : 'There are no sales records in this response.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF69756E), height: 1.45),
          ),
        ],
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.error,
    required this.onRetry,
    required this.onReauthenticate,
  });

  final Object? error;
  final VoidCallback onRetry;
  final VoidCallback? onReauthenticate;

  @override
  Widget build(BuildContext context) {
    final apiError = error is PosApiException ? error as PosApiException : null;
    final isUnauthorized = apiError?.isUnauthorized ?? false;
    final isForbidden = apiError?.statusCode == 403;
    return SectionCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 12),
        child: Column(
          children: [
            Icon(
              isUnauthorized || isForbidden
                  ? Icons.lock_outline
                  : Icons.cloud_off_outlined,
              size: 32,
              color: const Color(0xFFB54735),
            ),
            const SizedBox(height: 12),
            Text(
              isUnauthorized
                  ? 'Authentication required'
                  : isForbidden
                  ? 'Access denied'
                  : 'Sales are unavailable',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 7),
            Text(
              apiError?.message ?? 'Something went wrong while loading sales.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF69756E), height: 1.4),
            ),
            const SizedBox(height: 14),
            if ((apiError?.requiresToken == true || isUnauthorized) &&
                onReauthenticate != null) ...[
              FilledButton.icon(
                onPressed: onReauthenticate,
                icon: const Icon(Icons.login),
                label: const Text('Sign in again'),
              ),
              const SizedBox(height: 8),
            ],
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

void _showSaleDetails(BuildContext context, Sale sale, String? outletName) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        'Receipt ${sale.showUuid?.isNotEmpty == true ? sale.showUuid : sale.id}',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Receipt ID: ${sale.id.isEmpty ? '—' : sale.id}'),
          Text('Payable amount: ${sale.totalPrice?.toStringAsFixed(2) ?? '—'}'),
          Text(
            'Payment method: ${sale.paymentType?.isNotEmpty == true ? sale.paymentType : '—'}',
          ),
          Text(
            'Order option: ${sale.orderOption?.isNotEmpty == true ? sale.orderOption : '—'}',
          ),
          Text('Date: ${sale.createdAt?.toLocal() ?? '—'}'),
          Text(
            'Outlet: ${outletName?.isNotEmpty == true ? outletName : (sale.outletId.isEmpty ? '—' : 'Outlet ${sale.outletId}')}',
          ),
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

class _CountBanner extends StatelessWidget {
  const _CountBanner({required this.total, required this.showing});

  final int? total;
  final int showing;

  @override
  Widget build(BuildContext context) => SectionCard(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    child: Row(
      children: [
        const Icon(Icons.list_alt, color: Color(0xFF17834B)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Loaded $showing of ${total ?? showing} receipt records',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          'Showing $showing',
          style: const TextStyle(fontSize: 12, color: Color(0xFF69756E)),
        ),
      ],
    ),
  );
}

class _SaleTile extends StatelessWidget {
  const _SaleTile({required this.sale, this.outletName});

  final Sale sale;
  final String? outletName;

  @override
  Widget build(BuildContext context) {
    final timestamp = sale.createdAt ?? sale.chargedAt;
    final subtitle = [
      if (timestamp != null) _formatDate(timestamp),
      if (outletName?.isNotEmpty == true) outletName!,
      if (outletName?.isNotEmpty != true && sale.outletId.isNotEmpty)
        'Outlet ${sale.outletId}',
    ].join(' | ');
    return GestureDetector(
      onTap: () => _showSaleDetails(context, sale, outletName),
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
                Icons.receipt_outlined,
                color: Color(0xFF17834B),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Receipt ${sale.showUuid?.isNotEmpty == true ? sale.showUuid : sale.id}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF69756E),
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              sale.totalPrice == null
                  ? '—'
                  : sale.totalPrice!.toStringAsFixed(2),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = (local.hour % 12 == 0 ? 12 : local.hour % 12).toString();
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${months[local.month - 1]} ${local.year}, '
        '$hour:$minute ${local.hour < 12 ? 'AM' : 'PM'}';
  }
}
