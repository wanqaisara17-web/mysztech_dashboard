import 'package:flutter/material.dart';

import '../../../core/api/pos_api_service.dart';
import '../../../core/local/local_workspace.dart';
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
  });

  final PosApiService apiService;
  final VoidCallback? onReauthenticate;
  final LocalWorkspace? localWorkspace;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  late final List<Widget> _pages;
  final _dashboardKey = GlobalKey<DashboardScreenState>();
  final _itemsKey = GlobalKey<ItemsScreenState>();
  final _stockKey = GlobalKey<StockScreenState>();
  late final LocalWorkspace _workspace =
      widget.localWorkspace ?? (LocalWorkspace()..load());

  @override
  void initState() {
    super.initState();
    _pages = [
      DashboardScreen(
        key: _dashboardKey,
        apiService: widget.apiService,
        onOpenSales: () => _select(1),
        onOpenLowStock: _openLowStock,
      ),
      SalesScreen(
        apiService: widget.apiService,
        onReauthenticate: widget.onReauthenticate,
      ),
      StockScreen(
        key: _stockKey,
        apiService: widget.apiService,
        onConnect: widget.onReauthenticate ?? () => _select(1),
        workspace: _workspace,
        onOpenLocalItems: () => _select(3),
      ),
      ItemsScreen(
        key: _itemsKey,
        apiService: widget.apiService,
        onConnect: widget.onReauthenticate ?? () => _select(1),
        workspace: _workspace,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: IndexedStack(index: _selectedIndex, children: _pages),
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
