import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_monitoring_app/app.dart';
import 'package:pos_monitoring_app/core/api/pos_api_service.dart';
import 'package:pos_monitoring_app/core/local/local_workspace.dart';
import 'package:pos_monitoring_app/core/models/authenticated_user.dart';
import 'package:pos_monitoring_app/core/models/inventory_movement.dart';
import 'package:pos_monitoring_app/core/models/inventory_stock.dart';
import 'package:pos_monitoring_app/core/models/item.dart';
import 'package:pos_monitoring_app/core/models/sales_page.dart';
import 'package:pos_monitoring_app/core/models/outlet.dart';
import 'package:pos_monitoring_app/core/models/sales_history.dart';
import 'package:pos_monitoring_app/core/notifications/low_stock_notification_service.dart';
import 'package:pos_monitoring_app/features/dashboard/screens/app_shell.dart';
import 'package:pos_monitoring_app/features/sales/screens/sales_screen.dart';

class _FakeApiService implements PosApiService {
  _FakeApiService({
    this.items = const [],
    this.stock = const [],
    this.outlets = const [Outlet(id: 'outlet-1', name: 'Demo Outlet')],
  });

  final List<PosItem> items;
  final List<InventoryStock> stock;
  final List<Outlet> outlets;
  String? token;
  @override
  InventoryRetrievedCallback? onInventoryRetrieved;
  @override
  String? selectedOutletId;
  String? loginEmail;
  String? loginPassword;
  String? licenseKey;
  int refreshCount = 0;
  bool unauthorized = false;

  @override
  Future<AuthenticatedUser> login({
    required String email,
    required String password,
    required String licenseKey,
  }) async {
    loginEmail = email;
    loginPassword = password;
    this.licenseKey = licenseKey;
    setToken('session-token');
    return AuthenticatedUser(name: 'Demo User', email: email);
  }

  @override
  Future<SalesPage> getSales({
    bool forceRefresh = false,
    int page = 1,
    String? outletId,
  }) async {
    if (forceRefresh) refreshCount++;
    if (unauthorized) {
      throw const PosApiException('Your token was rejected.', statusCode: 401);
    }
    return SalesPage.fromJson({
      'is_success': true,
      'status_code': 200,
      'data': <dynamic>[],
      'paginator': {'total': 0},
    });
  }

  @override
  Future<List<Outlet>> getOutlets({bool forceRefresh = false}) async => outlets;

  @override
  Future<SalesHistory> getCompleteSalesHistory({String? outletId}) async =>
      const SalesHistory(sales: [], total: 0, isComplete: true);

  @override
  void setToken(String value) {
    token = value;
    selectedOutletId = null;
  }

  @override
  void selectOutlet(String outletId) => selectedOutletId = outletId;

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
  testWidgets('login sends email, password and license key then opens app', (
    tester,
  ) async {
    final api = _FakeApiService();
    await tester.pumpWidget(
      PosMonitoringApp(
        apiService: api,
        notificationService: LowStockNotificationService(
          client: _FakeNotificationClient(),
          stateStore: _FakeNotificationStateStore(),
          isAndroid: false,
        ),
      ),
    );

    expect(find.text('Mysztech Store Assistant'), findsOneWidget);
    expect(find.text('Sign in to your POS production account'), findsOneWidget);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'staff@example.com');
    await tester.enterText(fields.at(1), 'private-password');
    await tester.enterText(fields.at(2), '66666666666666666666');
    expect(
      tester.widget<TextFormField>(fields.at(2)).controller!.text,
      '66666-66666-66666-66666',
    );
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(api.loginEmail, 'staff@example.com');
    expect(api.loginPassword, 'private-password');
    expect(api.licenseKey, '66666-66666-66666-66666');
    expect(api.token, 'session-token');
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
  });

  testWidgets('Dashboard AI preview button shows the coming soon message', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(apiService: _FakeApiService(), onReauthenticate: () {}),
      ),
    );
    await tester.pumpAndSettle();

    final previewButton = find.byTooltip(
      'Preview the upcoming Mysztech AI assistant',
    );
    expect(find.text('Mysztech AI'), findsOneWidget);
    expect(previewButton, findsOneWidget);
    await tester.tap(previewButton);
    await tester.pumpAndSettle();

    expect(find.text('Mysztech AI \u2014 Coming Soon!'), findsOneWidget);
  });

  testWidgets('running notification tap routes after widget build completes', (
    tester,
  ) async {
    final client = _FakeNotificationClient();
    final api = _FakeApiService(
      outlets: const [
        Outlet(id: 'outlet-1', name: 'Demo Outlet'),
        Outlet(id: 'outlet-2', name: 'Second Outlet'),
      ],
      stock: const [
        InventoryStock(
          inventoryId: 'inv-1',
          itemName: 'Green Tea',
          quantity: 1,
          lowStockThreshold: 2,
          outletId: 'outlet-2',
        ),
      ],
    );
    await tester.pumpWidget(
      PosMonitoringApp(
        apiService: api,
        notificationService: _notificationService(client),
      ),
    );
    await _signIn(tester);
    await tester.pumpAndSettle();

    client.tap(
      const LowStockNotificationTarget(
        accountIdentity: 'staff@example.com',
        outletId: 'outlet-2',
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(api.selectedOutletId, 'outlet-2');
    expect(find.text('Second Outlet'), findsOneWidget);
    expect(find.text('Green Tea'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Low Stock'))
          .selected,
      isTrue,
    );
  });

  testWidgets('cold-start tap waits for authentication before routing', (
    tester,
  ) async {
    final target = const LowStockNotificationTarget(
      accountIdentity: 'staff@example.com',
      outletId: 'outlet-1',
    );
    final client = _FakeNotificationClient()..launchPayload = target.encode();
    final api = _FakeApiService();
    await tester.pumpWidget(
      PosMonitoringApp(
        apiService: api,
        notificationService: _notificationService(client),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sign in to your POS production account'), findsOneWidget);

    await _signIn(tester);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Demo Outlet'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Low Stock'))
          .selected,
      isTrue,
    );
  });

  testWidgets('logout confirmation can be cancelled', (tester) async {
    final client = _FakeNotificationClient();
    final api = _FakeApiService();
    await tester.pumpWidget(
      PosMonitoringApp(
        apiService: api,
        notificationService: _notificationService(client),
      ),
    );
    await _signIn(tester);

    await tester.tap(find.byTooltip('Application menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(api.token, 'session-token');
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(client.cancelCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('confirmed logout clears session and allows signing in again', (
    tester,
  ) async {
    final client = _FakeNotificationClient();
    final api = _FakeApiService();
    await tester.pumpWidget(
      PosMonitoringApp(
        apiService: api,
        notificationService: _notificationService(client),
      ),
    );
    await _signIn(tester);

    await tester.tap(find.byTooltip('Application menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Log out'));
    await tester.pumpAndSettle();

    expect(api.token, '');
    expect(client.cancelCount, greaterThan(0));
    expect(find.text('Sign in to your POS production account'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    client.tap(
      const LowStockNotificationTarget(
        accountIdentity: 'staff@example.com',
        outletId: 'outlet-1',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sign in to your POS production account'), findsOneWidget);

    await _signIn(tester);
    expect(api.token, 'session-token');
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sales shows empty response returned by the API', (tester) async {
    final api = _FakeApiService();
    await tester.pumpWidget(MaterialApp(home: SalesScreen(apiService: api)));
    await tester.pumpAndSettle();

    expect(find.text('No sales records yet'), findsOneWidget);
  });

  testWidgets('expired session offers sign in again', (tester) async {
    final api = _FakeApiService()..unauthorized = true;
    var reauthenticated = false;
    await tester.pumpWidget(
      MaterialApp(
        home: SalesScreen(
          apiService: api,
          onReauthenticate: () => reauthenticated = true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Authentication required'), findsOneWidget);
    await tester.tap(find.text('Sign in again'));
    expect(reauthenticated, isTrue);
  });

  testWidgets('Items supports search, details, and local label action', (
    tester,
  ) async {
    final api = _FakeApiService(
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
    expect(find.text('Create local label'), findsOneWidget);
  });

  testWidgets('Stock marks quantities at the API threshold as low stock', (
    tester,
  ) async {
    final api = _FakeApiService(
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
    await tester.tap(find.text('Stock').last);
    await tester.pumpAndSettle();

    expect(find.text('Green Tea'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.textContaining('at or below API threshold'), findsOneWidget);
  });

  testWidgets('empty API lists and narrow stock tabs render cleanly', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: AppShell(apiService: _FakeApiService())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Total reported by the sales list'), findsOneWidget);
    expect(find.text('No inventory records returned'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Stock').last);
    await tester.pumpAndSettle();
    expect(find.text('No inventory records returned.'), findsOneWidget);
    expect(find.text('Movements'), findsOneWidget);
    expect(find.text('On-device'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Movements').first);
    await tester.pumpAndSettle();
    expect(find.text('No stock movements returned.'), findsOneWidget);

    await tester.tap(find.text('Items').last);
    await tester.pumpAndSettle();
    expect(find.text('No items returned by the POS.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('local items stay separate and appear in on-device stock', (
    tester,
  ) async {
    const localChannel = MethodChannel('test/local_workspace');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(localChannel, (call) async {
          if (call.method == 'loadWorkspace') return '[]';
          if (call.method == 'saveWorkspace') return true;
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(localChannel, null),
    );
    final workspace = LocalWorkspace(channel: localChannel);
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          apiService: _FakeApiService(),
          localWorkspace: workspace,
        ),
      ),
    );
    await tester.tap(find.text('Items').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('On-device'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byTooltip('Add local item'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Local Lemon');
    await tester.enterText(fields.at(1), 'LEM-1');
    await tester.enterText(fields.at(2), '0123456789');
    await tester.enterText(fields.at(3), 'Fruit');
    await tester.enterText(fields.at(4), '1.25');
    await tester.enterText(fields.at(5), '2');
    await tester.enterText(fields.at(6), '3');
    await tester.drag(find.byType(ListView).last, const Offset(0, -600));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Save on this device'));
    await tester.pumpAndSettle();

    expect(find.text('LOCAL ONLY · Not synced to POS'), findsOneWidget);
    expect(find.text('Local Lemon'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'LEM-1');
    await tester.pumpAndSettle();
    expect(find.text('Local Lemon'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'no-match');
    await tester.pumpAndSettle();
    expect(find.text('No local items match this search.'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Local Lemon').last);
    await tester.pumpAndSettle();
    final editFields = find.byType(TextFormField);
    await tester.enterText(editFields.at(5), '1');
    await tester.drag(find.byType(ListView).last, const Offset(0, -600));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Save on this device'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Preview local label'));
    await tester.pumpAndSettle();
    expect(find.text('Category: Fruit'), findsOneWidget);
    expect(find.text('SKU: LEM-1'), findsOneWidget);
    expect(find.text('Barcode: 0123456789'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Stock').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('On-device'));
    await tester.pumpAndSettle();
    expect(find.text('Local Lemon'), findsOneWidget);
    expect(find.textContaining('Low local stock'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(
      find.textContaining('On-device counts do not sync to POS'),
      findsOneWidget,
    );
    await tester.tap(find.text('Items').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Local Lemon').last);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -700));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Delete local item'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(find.text('Your on-device catalog is empty.'), findsOneWidget);
  });
}

class _FakeNotificationClient implements LowStockNotificationClient {
  NotificationTapCallback? onTap;
  String? launchPayload;
  int cancelCount = 0;

  @override
  Future<String?> initialize(NotificationTapCallback onTap) async {
    this.onTap = onTap;
    return launchPayload;
  }

  void tap(LowStockNotificationTarget target) => onTap?.call(target);

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<bool> areNotificationsEnabled() async => false;

  @override
  Future<void> cancelAll() async {
    cancelCount++;
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {}
}

class _FakeNotificationStateStore implements LowStockNotificationStateStore {
  @override
  Future<Set<String>> load(String accountIdentity, String outletId) async =>
      <String>{};

  @override
  Future<void> save(
    String accountIdentity,
    String outletId,
    Set<String> inventoryIds,
  ) async {}
}

LowStockNotificationService _notificationService(
  _FakeNotificationClient client,
) => LowStockNotificationService(
  client: client,
  stateStore: _FakeNotificationStateStore(),
  isAndroid: true,
);

Future<void> _signIn(WidgetTester tester) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), 'staff@example.com');
  await tester.enterText(fields.at(1), 'password');
  await tester.enterText(fields.at(2), '66666666666666666666');
  await tester.tap(find.text('Sign in'));
  await tester.pumpAndSettle();
}
