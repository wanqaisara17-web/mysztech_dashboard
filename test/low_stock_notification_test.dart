import 'package:flutter_test/flutter_test.dart';
import 'package:pos_monitoring_app/core/models/inventory_stock.dart';
import 'package:pos_monitoring_app/core/notifications/low_stock_notification_service.dart';

void main() {
  test('sends an initial alert with item count and actual outlet name', () async {
    final client = _FakeNotificationClient();
    final service = _service(client);
    await service.initialize((_) {});

    final count = await _process(service, [
      _stock('inv-1'),
      _stock('inv-2'),
      _stock('inv-3'),
    ]);

    expect(count, 3);
    expect(client.shown, hasLength(1));
    expect(client.shown.single.title, 'Low Stock Alert');
    expect(
      client.shown.single.body,
      '3 inventory items at Demo Cafe have reached their minimum stock level.',
    );
  });

  test('notification count matches Stock low-stock criteria', () async {
    final client = _FakeNotificationClient();
    final service = _service(client);
    await service.initialize((_) {});

    final count = await _process(service, [
      _stock('at-threshold', quantity: 2),
      _stock('above-threshold', quantity: 3),
      _stock('disabled', quantity: 1, enabled: false),
      const InventoryStock(
        inventoryId: 'without-threshold',
        itemName: 'No threshold',
        quantity: 1,
        lowStockThreshold: null,
      ),
    ]);

    expect(count, 1);
    expect(client.shown, hasLength(1));
    expect(client.shown.single.body, contains('1 inventory item'));
  });

  test('does not repeat alerts for items that remain low', () async {
    final client = _FakeNotificationClient();
    final service = _service(client);
    await service.initialize((_) {});
    await _process(service, [_stock('inv-1')]);

    final duplicateCount = await _process(service, [_stock('inv-1')]);

    expect(duplicateCount, 0);
    expect(client.shown, hasLength(1));
  });

  test('alerts for additional low-stock items only', () async {
    final client = _FakeNotificationClient();
    final service = _service(client);
    await service.initialize((_) {});
    await _process(service, [_stock('inv-1')]);

    final newCount = await _process(service, [
      _stock('inv-1'),
      _stock('inv-2'),
      _stock('inv-3'),
    ]);

    expect(newCount, 2);
    expect(client.shown, hasLength(2));
    expect(client.shown.last.body, contains('2 inventory items'));
  });

  test('a restocked item can notify again when it becomes low', () async {
    final client = _FakeNotificationClient();
    final service = _service(client);
    await service.initialize((_) {});
    await _process(service, [_stock('inv-1')]);
    await _process(service, [_stock('inv-1', quantity: 8)]);

    final lowAgain = await _process(service, [_stock('inv-1')]);

    expect(lowAgain, 1);
    expect(client.shown, hasLength(2));
  });

  test('notification history is isolated by account and outlet', () async {
    final client = _FakeNotificationClient();
    final service = _service(client);
    await service.initialize((_) {});
    await _process(
      service,
      [_stock('inv-1')],
      account: 'account-a',
      outlet: 'outlet-a',
    );
    await _process(
      service,
      [_stock('inv-1')],
      account: 'account-b',
      outlet: 'outlet-a',
    );
    await _process(
      service,
      [_stock('inv-1')],
      account: 'account-a',
      outlet: 'outlet-b',
    );
    await _process(
      service,
      [_stock('inv-1')],
      account: 'account-a',
      outlet: 'outlet-a',
    );

    expect(client.shown, hasLength(3));
  });

  test('incomplete inventory does not notify or reset saved state', () async {
    final client = _FakeNotificationClient();
    final service = _service(client);
    await service.initialize((_) {});
    await _process(service, [_stock('inv-1')]);
    await _process(service, [_stock('inv-1', quantity: 8)], complete: false);

    final sameLowItem = await _process(service, [_stock('inv-1')]);
    expect(sameLowItem, 0);
    expect(client.shown, hasLength(1));

    final initialAfterOnlyIncomplete = _service(_FakeNotificationClient());
    await initialAfterOnlyIncomplete.initialize((_) {});
    final unconfirmedCount = await _process(initialAfterOnlyIncomplete, [
      _stock('inv-2'),
    ], complete: false);
    final firstCompleteCount = await _process(initialAfterOnlyIncomplete, [
      _stock('inv-2'),
    ]);
    expect(unconfirmedCount, 0);
    expect(firstCompleteCount, 1);
  });

  test('permission denial is graceful and sends no notification', () async {
    final client = _FakeNotificationClient()..permissionGranted = false;
    final service = _service(client);
    await service.initialize((_) {});
    expect(await service.requestPermissionIfNeeded(), isFalse);

    await expectLater(_process(service, [_stock('inv-1')]), completes);
    expect(client.shown, isEmpty);
    expect(client.permissionRequests, 1);
  });

  test(
    'logout cancellation suppresses queued alerts until authentication',
    () async {
      final client = _FakeNotificationClient();
      final service = _service(client);
      await service.initialize((_) {});
      await service.cancelAll();

      expect(await _process(service, [_stock('inv-1')]), 0);
      expect(client.shown, isEmpty);
      expect(client.cancelCount, greaterThan(0));

      service.resume();
      expect(await _process(service, [_stock('inv-1')]), 1);
      expect(client.shown, hasLength(1));
    },
  );

  test(
    'cold-start and running notification taps deliver an outlet target',
    () async {
      final target = LowStockNotificationTarget(
        accountIdentity: 'account-a',
        outletId: 'outlet-a',
      );
      final client = _FakeNotificationClient()..launchPayload = target.encode();
      final service = _service(client);
      final tapped = <LowStockNotificationTarget>[];

      await service.initialize(tapped.add);
      client.onTap?.call(target);

      expect(tapped, hasLength(2));
      expect(
        tapped.map((value) => value.accountIdentity),
        everyElement('account-a'),
      );
      expect(tapped.map((value) => value.outletId), everyElement('outlet-a'));
    },
  );
}

LowStockNotificationService _service(_FakeNotificationClient client) =>
    LowStockNotificationService(
      client: client,
      stateStore: _MemoryNotificationStateStore(),
      isAndroid: true,
    );

Future<int> _process(
  LowStockNotificationService service,
  List<InventoryStock> stock, {
  String account = 'account-a',
  String outlet = 'outlet-a',
  bool complete = true,
}) => service.processInventory(
  accountIdentity: account,
  outletId: outlet,
  outletName: 'Demo Cafe',
  inventory: stock,
  isComplete: complete,
);

InventoryStock _stock(String id, {num quantity = 1, bool? enabled}) =>
    InventoryStock(
      inventoryId: id,
      itemName: id,
      quantity: quantity,
      lowStockThreshold: 2,
      outletId: 'outlet-a',
      enabled: enabled,
    );

class _FakeNotificationClient implements LowStockNotificationClient {
  bool permissionGranted = true;
  int permissionRequests = 0;
  int cancelCount = 0;
  final List<_ShownNotification> shown = [];
  NotificationTapCallback? onTap;
  String? launchPayload;

  @override
  Future<String?> initialize(NotificationTapCallback callback) async {
    onTap = callback;
    return launchPayload;
  }

  @override
  Future<bool> areNotificationsEnabled() async => permissionGranted;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permissionGranted;
  }

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
  }) async {
    shown.add(_ShownNotification(title: title, body: body, payload: payload));
  }
}

class _MemoryNotificationStateStore implements LowStockNotificationStateStore {
  final Map<String, Set<String>> _states = {};
  String _key(String account, String outlet) => '$account::$outlet';

  @override
  Future<Set<String>> load(String accountIdentity, String outletId) async =>
      Set<String>.of(
        _states[_key(accountIdentity, outletId)] ?? const <String>{},
      );

  @override
  Future<void> save(
    String accountIdentity,
    String outletId,
    Set<String> inventoryIds,
  ) async {
    _states[_key(accountIdentity, outletId)] = Set<String>.of(inventoryIds);
  }
}

class _ShownNotification {
  const _ShownNotification({
    required this.title,
    required this.body,
    required this.payload,
  });

  final String title;
  final String body;
  final String payload;
}
