import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_monitoring_app/core/api/pos_api_service.dart';
import 'package:pos_monitoring_app/core/models/sales_page.dart';
import 'package:pos_monitoring_app/core/models/item.dart';
import 'package:pos_monitoring_app/core/models/inventory_stock.dart';
import 'package:pos_monitoring_app/core/models/inventory_movement.dart';
import 'package:pos_monitoring_app/features/dashboard/screens/app_shell.dart';
import 'package:pos_monitoring_app/features/sales/screens/sales_screen.dart';

class _FakeApiService implements PosApiService {
  _FakeApiService(
    this.result, {
    this.onToken,
    this.items = const [],
    this.stock = const [],
  });

  final Future<SalesPage> Function() result;
  final void Function(String)? onToken;
  final List<PosItem> items;
  final List<InventoryStock> stock;
  String? token;
  int refreshCount = 0;

  @override
  Future<SalesPage> getSales({bool forceRefresh = false}) {
    if (forceRefresh) refreshCount++;
    return result();
  }

  @override
  void setToken(String value) {
    token = value;
    onToken?.call(value);
  }

  @override
  Future<List<PosItem>> getItems({bool forceRefresh = false}) async => items;

  @override
  Future<PosItem> getItem(String id) async =>
      items.firstWhere((item) => item.id == id);

  @override
  Future<List<InventoryStock>> getInventoryStock({
    bool forceRefresh = false,
  }) async => stock;

  @override
  Future<List<InventoryMovement>> getInventoryMovements({
    bool forceRefresh = false,
  }) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('sales screen shows documented empty response state', (
    tester,
  ) async {
    final api = _FakeApiService(
      () async => SalesPage.fromJson({
        'is_success': true,
        'status_code': 200,
        'data': <dynamic>[],
        'paginator': {
          'total': '0',
          'count': '0',
          'lastPage': '0',
          'perPage': '15',
        },
      }),
    );

    await tester.pumpWidget(MaterialApp(home: SalesScreen(apiService: api)));
    await tester.pumpAndSettle();

    expect(find.text('No sales records yet'), findsOneWidget);
    expect(find.textContaining('API reports 0 total sales'), findsOneWidget);
  });

  testWidgets('sales screen exposes retry for an authentication error', (
    tester,
  ) async {
    final api = _FakeApiService(
      () async => throw const PosApiException(
        'Your token was rejected. Supply a currently authorized staging token.',
        statusCode: 401,
      ),
    );

    await tester.pumpWidget(MaterialApp(home: SalesScreen(apiService: api)));
    await tester.pumpAndSettle();

    expect(find.text('Authentication required'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets(
    'missing token can be configured in a masked session-only field',
    (tester) async {
      final api = _FakeApiService(
        () async => throw const PosApiException(
          'Enter an authorized staging token to load sales.',
          requiresToken: true,
        ),
      );

      await tester.pumpWidget(MaterialApp(home: SalesScreen(apiService: api)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Configure token'));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.obscureText, isTrue);
      expect(
        find.text('Used only for this app session. It is not saved.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'Connect stores session token and refreshes Sales to the empty state',
    (tester) async {
      var connected = false;
      final api = _FakeApiService(() async {
        if (!connected) {
          throw const PosApiException(
            'Enter an authorized staging token.',
            requiresToken: true,
          );
        }
        return SalesPage.fromJson({
          'is_success': true,
          'status_code': 200,
          'data': <dynamic>[],
          'paginator': {'total': 0},
        });
      }, onToken: (_) => connected = true);

      await tester.pumpWidget(MaterialApp(home: SalesScreen(apiService: api)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Configure token'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Bearer local-test-token');
      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();

      expect(api.token, 'Bearer local-test-token');
      expect(api.refreshCount, 1);
      expect(find.text('No sales records yet'), findsOneWidget);
    },
  );

  testWidgets('connecting in Sales refreshes the cached Dashboard summary', (
    tester,
  ) async {
    var connected = false;
    final api = _FakeApiService(() async {
      if (!connected) {
        throw const PosApiException(
          'Enter an authorized staging token.',
          requiresToken: true,
        );
      }
      return SalesPage.fromJson({
        'is_success': true,
        'status_code': 200,
        'data': <dynamic>[],
        'paginator': {'total': 0},
      });
    }, onToken: (_) => connected = true);

    await tester.pumpWidget(MaterialApp(home: AppShell(apiService: api)));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Sales'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Configure token'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'local-test-token');
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Dashboard'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No sales records yet'), findsOneWidget);
    expect(find.text('Sales data unavailable'), findsNothing);
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets(
    'navigation includes dashboard sales stock and items placeholders',
    (tester) async {
      final api = _FakeApiService(
        () async => SalesPage.fromJson({
          'data': <dynamic>[],
          'paginator': {'total': '0'},
        }),
      );

      await tester.pumpWidget(MaterialApp(home: AppShell(apiService: api)));

      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Sales'), findsAtLeastNWidgets(1));
      expect(find.text('Stock'), findsOneWidget);
      expect(find.text('Items'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Stock'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No inventory records returned.'), findsOneWidget);
    },
  );

  testWidgets('Stock marks records at the API threshold as low stock', (
    tester,
  ) async {
    final api = _FakeApiService(
      () async => SalesPage.fromJson({
        'data': <dynamic>[],
        'paginator': {'total': 0},
      }),
      stock: const [
        InventoryStock(
          inventoryId: '9',
          itemName: 'Green Tea',
          quantity: 2,
          lowStockThreshold: 3,
          outletId: '1',
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp(home: AppShell(apiService: api)));
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Stock'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Green Tea'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Low stock · at or below API threshold'), findsOneWidget);
  });

  testWidgets('Items supports search, item details, and local label action', (
    tester,
  ) async {
    final api = _FakeApiService(
      () async => SalesPage.fromJson({
        'data': <dynamic>[],
        'paginator': {'total': 0},
      }),
      items: const [
        PosItem(
          id: '4',
          name: 'Green Tea',
          sku: 'TEA-4',
          barcode: '123456',
          price: 3.5,
          categoryId: '2',
          categoryName: 'Drinks',
        ),
        PosItem(id: '5', name: 'Coffee', sku: 'COF-5', price: 4),
      ],
    );
    await tester.pumpWidget(MaterialApp(home: AppShell(apiService: api)));
    await tester.tap(find.byIcon(Icons.category_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Green Tea'), findsOneWidget);
    expect(find.text('Coffee'), findsOneWidget);
    expect(find.byTooltip('Create local label'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pumpAndSettle();
    expect(find.text('Green Tea'), findsOneWidget);
    expect(find.text('Coffee'), findsNothing);
    await tester.tap(find.text('Green Tea'));
    await tester.pumpAndSettle();
    expect(find.text('Item details'), findsOneWidget);
    expect(find.text('Drinks'), findsOneWidget);
    expect(find.text('123456'), findsOneWidget);
    expect(find.text('Create local label'), findsOneWidget);
  });
}
