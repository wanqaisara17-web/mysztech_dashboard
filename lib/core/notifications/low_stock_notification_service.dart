import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/inventory_stock.dart';

typedef NotificationTapCallback = void Function(
  LowStockNotificationTarget target,
);

class LowStockNotificationTarget {
  const LowStockNotificationTarget({
    required this.accountIdentity,
    required this.outletId,
  });

  final String accountIdentity;
  final String outletId;

  String encode() =>
      jsonEncode({'account': accountIdentity, 'outlet': outletId});

  static LowStockNotificationTarget? decode(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic>) return null;
      final account = decoded['account']?.toString() ?? '';
      final outlet = decoded['outlet']?.toString() ?? '';
      if (account.isEmpty || outlet.isEmpty) return null;
      return LowStockNotificationTarget(
        accountIdentity: account,
        outletId: outlet,
      );
    } on FormatException {
      return null;
    }
  }
}

abstract interface class LowStockNotificationClient {
  Future<String?> initialize(NotificationTapCallback onTap);
  Future<bool> requestPermission();
  Future<bool> areNotificationsEnabled();
  Future<void> cancelAll();
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String payload,
  });
}

abstract interface class LowStockNotificationStateStore {
  Future<Set<String>> load(String accountIdentity, String outletId);
  Future<void> save(
    String accountIdentity,
    String outletId,
    Set<String> inventoryIds,
  );
}

class MethodChannelLowStockNotificationStateStore
    implements LowStockNotificationStateStore {
  const MethodChannelLowStockNotificationStateStore({
    this._channel = const MethodChannel(
      'com.example.pos_monitoring_app/local_workspace',
    ),
  });

  final MethodChannel _channel;

  @override
  Future<Set<String>> load(String accountIdentity, String outletId) async {
    final values = await _channel.invokeListMethod<String>(
      'loadLowStockNotificationState',
      {'account': accountIdentity, 'outlet': outletId},
    );
    return (values ?? const <String>[]).toSet();
  }

  @override
  Future<void> save(
    String accountIdentity,
    String outletId,
    Set<String> inventoryIds,
  ) async {
    await _channel.invokeMethod<void>('saveLowStockNotificationState', {
      'account': accountIdentity,
      'outlet': outletId,
      'inventoryIds': inventoryIds.toList(growable: false),
    });
  }
}

class FlutterLocalNotificationClient implements LowStockNotificationClient {
  FlutterLocalNotificationClient({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  static const _channelId = 'low_stock_alerts';
  static const _channelName = 'Low stock alerts';

  @override
  Future<String?> initialize(NotificationTapCallback onTap) async {
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final target = LowStockNotificationTarget.decode(response.payload);
        if (target != null) onTap(target);
      },
    );
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Alerts when POS inventory reaches its low-stock level.',
        importance: Importance.high,
      ),
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp != true) return null;
    return launch?.notificationResponse?.payload;
  }

  @override
  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<bool> areNotificationsEnabled() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.areNotificationsEnabled() ?? false;
  }

  @override
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription:
              'Alerts when POS inventory reaches its low-stock level.',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: payload,
    );
  }
}

class LowStockNotificationService {
  LowStockNotificationService({
    LowStockNotificationClient? client,
    LowStockNotificationStateStore? stateStore,
    bool? isAndroid,
  }) : _client = client ?? FlutterLocalNotificationClient(),
       _stateStore =
           stateStore ?? const MethodChannelLowStockNotificationStateStore(),
       _isAndroid =
           isAndroid ?? defaultTargetPlatform == TargetPlatform.android;

  final LowStockNotificationClient _client;
  final LowStockNotificationStateStore _stateStore;
  final bool _isAndroid;
  bool _ready = false;
  Future<void>? _initialization;
  Future<bool>? _permissionRequest;
  final Map<String, Future<int>> _inventoryOperations = {};
  int _notificationSequence = 0;
  int _notificationGeneration = 0;
  bool _notificationsActive = true;

  Future<void> initialize(NotificationTapCallback onTap) =>
      _initialization ??= _initialize(onTap);

  Future<void> _initialize(NotificationTapCallback onTap) async {
    if (!_isAndroid) return;
    try {
      final launchPayload = await _client.initialize(onTap);
      _ready = true;
      final launchTarget = LowStockNotificationTarget.decode(launchPayload);
      if (launchTarget != null) onTap(launchTarget);
    } catch (_) {
      _ready = false;
    }
  }

  Future<bool> requestPermissionIfNeeded() =>
      _permissionRequest ??= _requestPermissionIfNeeded();

  Future<bool> _requestPermissionIfNeeded() async {
    await _initialization;
    if (!_isAndroid || !_ready) return false;
    try {
      if (await _client.areNotificationsEnabled()) return true;
      return await _client.requestPermission();
    } catch (_) {
      return false;
    }
  }

  Future<int> processInventory({
    required String accountIdentity,
    required String outletId,
    required String outletName,
    required List<InventoryStock> inventory,
    required bool isComplete,
  }) async {
    if (!_notificationsActive ||
        !_isAndroid ||
        !_ready ||
        !isComplete ||
        accountIdentity.isEmpty ||
        outletId.isEmpty) {
      return 0;
    }

    final scope = '$accountIdentity\u0000$outletId';
    final previous = _inventoryOperations[scope] ?? Future<int>.value(0);
    final generation = _notificationGeneration;
    final operation = previous.then(
      (_) => _processInventory(
        accountIdentity: accountIdentity,
        outletId: outletId,
        outletName: outletName,
        inventory: inventory,
        generation: generation,
      ),
    );
    _inventoryOperations[scope] = operation;
    return operation;
  }

  Future<int> _processInventory({
    required String accountIdentity,
    required String outletId,
    required String outletName,
    required List<InventoryStock> inventory,
    required int generation,
  }) async {
    final currentLowIds = inventory
        .where((row) => row.inventoryId.isNotEmpty && row.isLowStock)
        .map((row) => row.inventoryId)
        .toSet();
    try {
      await _permissionRequest;
      final previousLowIds = await _stateStore.load(accountIdentity, outletId);
      final newlyLowIds = currentLowIds.difference(previousLowIds);
      if (generation == _notificationGeneration &&
          newlyLowIds.isNotEmpty &&
          await _client.areNotificationsEnabled() &&
          generation == _notificationGeneration) {
        final count = newlyLowIds.length;
        final noun = count == 1 ? 'item' : 'items';
        final verb = count == 1 ? 'has' : 'have';
        final possessive = count == 1 ? 'its' : 'their';
        _notificationSequence++;
        await _client.show(
          id:
              (DateTime.now().millisecondsSinceEpoch + _notificationSequence) &
              0x7fffffff,
          title: 'Low Stock Alert',
          body:
              '$count inventory $noun at $outletName $verb reached $possessive minimum stock level.',
          payload: LowStockNotificationTarget(
            accountIdentity: accountIdentity,
            outletId: outletId,
          ).encode(),
        );
      }
      await _stateStore.save(accountIdentity, outletId, currentLowIds);
      return newlyLowIds.length;
    } catch (_) {
      // Inventory and screen rendering remain independent of notification failures.
      return 0;
    }
  }

  Future<void> cancelAll() async {
    _notificationsActive = false;
    _notificationGeneration++;
    try {
      await _client.cancelAll();
    } catch (_) {
      // Keep invalidated work from sending, even if platform cancellation fails.
    }
    final pendingOperations = _inventoryOperations.values.toList();
    try {
      await Future.wait(pendingOperations);
    } catch (_) {
      // Cancellation should still clear notifications after an alert failure.
    }
    try {
      await _client.cancelAll();
    } catch (_) {
      // Notification cancellation must not prevent logout.
    }
  }

  void resume() {
    _notificationsActive = true;
  }
}
