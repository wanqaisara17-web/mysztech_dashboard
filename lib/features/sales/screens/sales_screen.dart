import 'package:flutter/material.dart';

import '../../../core/api/pos_api_service.dart';
import '../../../core/models/sale.dart';
import '../../../core/models/sales_page.dart';
import '../../../core/widgets/section_card.dart';
import '../../../shared/widgets/page_header.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({
    super.key,
    required this.apiService,
    this.onReauthenticate,
  });

  final PosApiService apiService;
  final VoidCallback? onReauthenticate;

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  late Future<SalesPage> _sales;

  @override
  void didUpdateWidget(covariant SalesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.apiService != widget.apiService) {
      _sales = widget.apiService.getSales(forceRefresh: true);
    }
  }

  @override
  void initState() {
    super.initState();
    _sales = widget.apiService.getSales();
  }

  void _retry() {
    setState(() {
      _sales = widget.apiService.getSales(forceRefresh: true);
    });
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () async => _retry(),
    child: CustomScrollView(
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
                      onPressed: _retry,
                      tooltip: 'Refresh sales',
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FutureBuilder<SalesPage>(
                  future: _sales,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const _LoadingState();
                    }
                    if (snapshot.hasError) {
                      return _ErrorState(
                        error: snapshot.error,
                        onRetry: _retry,
                        onReauthenticate: widget.onReauthenticate,
                      );
                    }
                    final page = snapshot.data!;
                    if (page.sales.isEmpty) {
                      return _EmptyState(total: page.total);
                    }
                    return Column(
                      children: [
                        _CountBanner(
                          total: page.total,
                          showing: page.sales.length,
                        ),
                        const SizedBox(height: 12),
                        ...page.sales.map(
                          (sale) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _SaleTile(sale: sale),
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
            '${total ?? showing} total records',
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
  const _SaleTile({required this.sale});

  final Sale sale;

  @override
  Widget build(BuildContext context) {
    final timestamp = sale.chargedAt ?? sale.createdAt;
    final subtitle = [
      if (sale.name?.isNotEmpty == true) sale.name!,
      if (timestamp != null) _formatDate(timestamp),
      if (sale.outletId.isNotEmpty) 'Outlet ${sale.outletId}',
    ].join(' · ');
    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F4EC),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.receipt_outlined, color: Color(0xFF17834B)),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sale.name?.isNotEmpty == true
                      ? sale.name!
                      : 'Sale ${sale.id}',
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
            sale.totalPrice == null ? '—' : sale.totalPrice.toString(),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = (local.hour % 12 == 0 ? 12 : local.hour % 12).toString();
    final minute = local.minute.toString().padLeft(2, '0');
    return '$month/$day/${local.year} · $hour:$minute ${local.hour < 12 ? 'AM' : 'PM'}';
  }
}
