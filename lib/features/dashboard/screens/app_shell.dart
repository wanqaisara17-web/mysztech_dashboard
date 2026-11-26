import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/pos_api_service.dart';
import '../../../core/local/local_workspace.dart';
import '../../../core/models/outlet.dart';
import '../../../core/models/authenticated_user.dart';
import '../../../core/models/inventory_stock.dart';
import '../../../core/notifications/low_stock_notification_service.dart';
import '../../items/screens/items_screen.dart';
import '../../sales/screens/sales_screen.dart';
import '../../stock/screens/stock_screen.dart';
import 'dashboard_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.apiService,
    this.onReauthenticate,
    this.localWorkspace,
    this.authenticatedUser,
    this.notificationService,
    this.notificationTarget,
    this.onNotificationTargetHandled,
  });

  final PosApiService apiService;
  final VoidCallback? onReauthenticate;
  final LocalWorkspace? localWorkspace;
  final AuthenticatedUser? authenticatedUser;
  final LowStockNotificationService? notificationService;
  final LowStockNotificationTarget? notificationTarget;
  final ValueChanged<LowStockNotificationTarget>? onNotificationTargetHandled;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  final _dashboardKey = GlobalKey<DashboardScreenState>();
  final _salesKey = GlobalKey<SalesScreenState>();
  final _itemsKey = GlobalKey<ItemsScreenState>();
  final _stockKey = GlobalKey<StockScreenState>();
  late final LocalWorkspace _workspace =
      widget.localWorkspace ?? (LocalWorkspace()..load());
  late final Future<List<Outlet>> _outletsFuture;
  List<Outlet> _outlets = const [];
  String? _selectedOutletId;
  LowStockNotificationTarget? _handledNotificationTarget;
  int _notificationNavigationGeneration = 0;

  @override
  void initState() {
    super.initState();
    widget.apiService.onInventoryRetrieved = _onInventoryRetrieved;
    final notificationService = widget.notificationService;
    if (notificationService != null) {
      unawaited(notificationService.requestPermissionIfNeeded());
    }
    _outletsFuture = widget.apiService.getOutlets();
    _outletsFuture.then((outlets) {
      if (!mounted || outlets.isEmpty) return;
      final selected = widget.apiService.selectedOutletId ?? outlets.first.id;
      widget.apiService.selectOutlet(selected);
      setState(() {
        _outlets = outlets;
        _selectedOutletId = selected;
      });
      final target = widget.notificationTarget;
      if (target != null) _handleNotificationTarget(target);
    });
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.apiService != widget.apiService) {
      oldWidget.apiService.onInventoryRetrieved = null;
      widget.apiService.onInventoryRetrieved = _onInventoryRetrieved;
    }
    if (widget.notificationTarget != null &&
        widget.notificationTarget != oldWidget.notificationTarget &&
        _outlets.isNotEmpty) {
      _handleNotificationTarget(widget.notificationTarget!);
    }
    if (widget.notificationTarget == null) {
      _handledNotificationTarget = null;
    }
  }

  @override
  void dispose() {
    widget.apiService.onInventoryRetrieved = null;
    super.dispose();
  }

  Future<void> _onInventoryRetrieved(
    String outletId,
    List<InventoryStock> inventory,
  ) async {
    final service = widget.notificationService;
    final account = widget.authenticatedUser?.notificationAccountIdentity;
    if (service == null || account == null) return;
    final outlets = _outlets.isEmpty ? await _outletsFuture : _outlets;
    if (!mounted ||
        widget.notificationService != service ||
        widget.authenticatedUser?.notificationAccountIdentity != account) {
      return;
    }
    final outlet = outlets.where((candidate) => candidate.id == outletId);
    final outletName = outlet.isEmpty || outlet.first.name.isEmpty
        ? 'Outlet $outletId'
        : outlet.first.name;
    await service.processInventory(
      accountIdentity: account,
      outletId: outletId,
      outletName: outletName,
      inventory: inventory,
      isComplete: true,
    );
  }

  void _handleNotificationTarget(LowStockNotificationTarget target) {
    if (_sameTarget(_handledNotificationTarget, target)) return;
    _handledNotificationTarget = target;
    final account = widget.authenticatedUser?.notificationAccountIdentity;
    final authorizedOutlet = _outlets.any(
      (outlet) => outlet.id == target.outletId,
    );
    if (account == null ||
        account != target.accountIdentity ||
        !authorizedOutlet) {
      widget.onNotificationTargetHandled?.call(target);
      return;
    }
    widget.apiService.selectOutlet(target.outletId);
    widget.onNotificationTargetHandled?.call(target);
    final generation = ++_notificationNavigationGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (generation != _notificationNavigationGeneration) return;
      if (_selectedOutletId != target.outletId) {
        setState(() => _selectedOutletId = target.outletId);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || generation != _notificationNavigationGeneration) return;
        _stockKey.currentState?.showLowStock();
        if (_selectedIndex != 2) setState(() => _selectedIndex = 2);
      });
    });
  }

  bool _sameTarget(
    LowStockNotificationTarget? left,
    LowStockNotificationTarget? right,
  ) =>
      left != null &&
      right != null &&
      left.accountIdentity == right.accountIdentity &&
      left.outletId == right.outletId;

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'You will need to sign in again to access the POS.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (shouldLogout == true && mounted) widget.onReauthenticate?.call();
  }

  List<Widget> get _pages => [
    DashboardScreen(
      key: _dashboardKey,
      apiService: widget.apiService,
      onOpenSales: () => _select(1),
      onOpenLowStock: _openLowStock,
      selectedOutletId: _selectedOutletId,
      selectedOutletName: _outletNames[_selectedOutletId],
    ),
    SalesScreen(
      key: _salesKey,
      apiService: widget.apiService,
      outletNames: _outletNames,
      selectedOutletId: _selectedOutletId,
      onReauthenticate: widget.onReauthenticate,
    ),
    StockScreen(
      key: _stockKey,
      apiService: widget.apiService,
      outletNames: _outletNames,
      selectedOutletId: _selectedOutletId,
      onConnect: widget.onReauthenticate ?? () => _select(1),
      workspace: _workspace,
      onOpenLocalItems: () => _select(3),
    ),
    ItemsScreen(
      key: _itemsKey,
      apiService: widget.apiService,
      selectedOutletId: _selectedOutletId,
      onConnect: widget.onReauthenticate ?? () => _select(1),
      workspace: _workspace,
    ),
  ];

  Map<String, String> get _outletNames => {...outletNamesById(_outlets)};

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          FutureBuilder<List<Outlet>>(
            future: _outletsFuture,
            builder: (context, snapshot) {
              final outlets = _outlets.isNotEmpty
                  ? _outlets
                  : snapshot.data ?? const <Outlet>[];
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Row(
                  children: [
                    if (outlets.isNotEmpty) ...[
                      const Icon(
                        Icons.store_outlined,
                        color: Color(0xFF17834B),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Outlet',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value:
                              outlets.any(
                                (outlet) => outlet.id == _selectedOutletId,
                              )
                              ? _selectedOutletId
                              : outlets.first.id,
                          underline: const SizedBox.shrink(),
                          items: outlets
                              .map(
                                (outlet) => DropdownMenuItem(
                                  value: outlet.id,
                                  child: Text(
                                    outlet.name.isEmpty
                                        ? 'Outlet ${outlet.id}'
                                        : outlet.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (id) {
                            if (id == null || id == _selectedOutletId) return;
                            widget.apiService.selectOutlet(id);
                            setState(() => _selectedOutletId = id);
                          },
                        ),
                      ),
                    ] else
                      const Spacer(),
                    PopupMenuButton<String>(
                      tooltip: 'Application menu',
                      icon: const Icon(Icons.more_vert),
                      onSelected: (action) {
                        if (action == 'logout') _confirmLogout();
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'logout',
                          child: Row(
                            children: [
                              Icon(Icons.logout),
                              SizedBox(width: 12),
                              Text('Log out'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          Expanded(
            child: IndexedStack(index: _selectedIndex, children: _pages),
          ),
        ],
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: _select,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long),
          label: 'Sales',
        ),
        NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined),
          selectedIcon: Icon(Icons.inventory_2),
          label: 'Stock',
        ),
        NavigationDestination(
          icon: Icon(Icons.category_outlined),
          selectedIcon: Icon(Icons.category),
          label: 'Items',
        ),
      ],
    ),
  );

  void _select(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
  }

  void _openLowStock() {
    _stockKey.currentState?.showLowStock();
    _select(2);
  }
}
