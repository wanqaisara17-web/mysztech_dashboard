import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_monitoring_app/core/api/pos_api_service.dart';

void main() {
  test('the default API base URL targets staging', () {
    final api = PosApiService();

    try {
      expect(api.baseUrl, posApiStagingUrl);
    } finally {
      api.close();
    }
  });

  test('setting token after missing-token state makes fresh authorized sales request', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requestCount = 0;
    var requestMethod = '';
    var requestPath = '';
    var authorization = '';
    final serverSubscription = server.listen((request) async {
      requestCount++;
      requestMethod = request.method;
      requestPath = request.uri.path;
      authorization =
          request.headers.value(HttpHeaders.authorizationHeader) ?? '';
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'is_success': true,
          'status_code': 200,
          'data': <dynamic>[],
          'paginator': {'total': 0},
        }),
      );
      await request.response.close();
    });
    final api = PosApiService(baseUrl: 'http://127.0.0.1:${server.port}/api');

    try {
      await expectLater(api.getSales(), throwsA(isA<PosApiException>()));
      api.setToken(' Bearer local-test-token ');
      final page = await api.getSales();

      expect(page.sales, isEmpty);
      expect(page.total, 0);
      expect(requestCount, 1);
      expect(requestMethod, 'GET');
      expect(requestPath, '/api/v2/sales/list');
      expect(authorization, 'Bearer local-test-token');
    } finally {
      api.close();
      await serverSubscription.cancel();
      await server.close(force: true);
    }
  });

  test('concurrent initial sales loads share one local HTTP request', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requestCount = 0;
    final serverSubscription = server.listen((request) async {
      requestCount++;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
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
      await request.response.close();
    });
    final api = PosApiService(
      baseUrl: 'http://127.0.0.1:${server.port}/api',
      token: 'local-test-token',
    );

    try {
      final dashboardLoad = api.getSales();
      final salesLoad = api.getSales();

      expect(identical(dashboardLoad, salesLoad), isTrue);
      await Future.wait([dashboardLoad, salesLoad]);
      expect(requestCount, 1);
    } finally {
      api.close();
      await serverSubscription.cancel();
      await server.close(force: true);
    }
  });

  test(
    'documented item and inventory GET endpoints use the session bearer token',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final paths = <String>[];
      final authHeaders = <String>[];
      final serverSubscription = server.listen((request) async {
        paths.add(request.uri.path);
        authHeaders.add(
          request.headers.value(HttpHeaders.authorizationHeader) ?? '',
        );
        request.response.headers.contentType = ContentType.json;
        final data = switch (request.uri.path) {
          '/api/v2/items/list' => [
            {
              'id': 'item-1',
              'name': 'Green Tea',
              'category_id': 'category-2',
              'barcode': '123456',
              'sku': 'TEA-1',
              'price': '3.50',
              'inventory_id': 'inventory-9',
              'tracking_enabled': true,
            },
          ],
          '/api/v2/categories/category-2' => {
            'id': 'category-2',
            'name': 'Drinks',
          },
          '/api/v2/items/item-1' => {
            'id': 'item-1',
            'name': 'Green Tea',
            'category_id': 'category-2',
            'barcode': '123456',
            'sku': 'TEA-1',
            'price': '3.50',
            'inventory_id': 'inventory-9',
            'tracking_enabled': true,
          },
          '/api/v2/inventory-outlet/list' => [
            {
              'inventory_id': 'inventory-9',
              'outlet_id': 'outlet-1',
              'current_quantity': '2',
              'low_stock_threshold': '3',
              'is_enabled': true,
            },
          ],
          '/api/v2/inventory-transactions/list' => [
            {
              'id': 'move-1',
              'inventory_id': 'inventory-9',
              'name': 'Green Tea',
              'type': 'adjustment',
              'quantity': '2',
              'stock_after': '2',
            },
          ],
          _ => <dynamic>[],
        };
        final isList = data is List;
        request.response.write(
          jsonEncode({
            'is_success': true,
            'status_code': 200,
            'data': data,
            if (isList) 'paginator': {'total': '${data.length}'},
          }),
        );
        await request.response.close();
      });
      final api = PosApiService(
        baseUrl: 'http://127.0.0.1:${server.port}/api',
        token: 'local-test-token',
      );

      try {
        final items = await api.getItems();
        final item = await api.getItem('item-1');
        final stock = await api.getInventoryStock();
        final movements = await api.getInventoryMovements();

        expect(items.single.name, 'Green Tea');
        expect(items.single.categoryName, 'Drinks');
        expect(items.single.price, 3.5);
        expect(item.barcode, '123456');
        expect(stock.single.itemName, 'Green Tea');
        expect(stock.single.quantity, 2);
        expect(stock.single.isLowStock, isTrue);
        expect(movements.single.stockAfter, 2);
        expect(paths, contains('/api/v2/items/list'));
        expect(paths, contains('/api/v2/items/item-1'));
        expect(paths, contains('/api/v2/inventory-outlet/list'));
        expect(paths, contains('/api/v2/inventory-transactions/list'));
        expect(authHeaders, everyElement('Bearer local-test-token'));
      } finally {
        api.close();
        await serverSubscription.cancel();
        await server.close(force: true);
      }
    },
  );
}
