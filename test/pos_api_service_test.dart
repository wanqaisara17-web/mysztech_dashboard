import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_monitoring_app/core/api/pos_api_service.dart';

void main() {
  test('the default API base URL targets production', () {
    final api = PosApiService();

    try {
      expect(api.baseUrl, posApiProductionUrl);
    } finally {
      api.close();
    }
  });

  test('setting token after missing-token state makes fresh authorized receipts request', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requestCount = 0;
    var requestMethod = '';
    var requestPath = '';
    var authorization = '';
    var outletId = '';
    final serverSubscription = server.listen((request) async {
      requestCount++;
      requestMethod = request.method;
      requestPath = request.uri.path;
      authorization =
          request.headers.value(HttpHeaders.authorizationHeader) ?? '';
      outletId = request.headers.value('outlet-id') ?? '';
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'is_success': true,
          'status_code': 200,
          'data': request.uri.path == '/api/v2/outlets/list'
              ? [
                  {'id': 'outlet-1'},
                ]
              : [
                  {
                    'id': 'receipt-1',
                    'outlet_id': 'outlet-1',
                    'open_order_name': 'Lunch order',
                    'payable_amount': '12.50',
                    'order_end_time': '2026-11-24T12:30:00Z',
                  },
                ],
          'paginator': {'total': 1},
        }),
      );
      await request.response.close();
    });
    final api = PosApiService(baseUrl: 'http://127.0.0.1:${server.port}/api');

    try {
      await expectLater(api.getSales(), throwsA(isA<PosApiException>()));
      api.setToken(' Bearer local-test-token ');
      final page = await api.getSales();

      expect(page.sales.single.name, 'Lunch order');
      expect(page.sales.single.totalPrice, 12.5);
      expect(page.total, 1);
      expect(requestCount, 2);
      expect(requestMethod, 'GET');
      expect(requestPath, '/api/v2/receipts/list');
      expect(authorization, 'Bearer local-test-token');
      expect(outletId, 'outlet-1');
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
          'data': request.uri.path == '/api/v2/outlets/list'
              ? [
                  {'id': 'outlet-1'},
                ]
              : <dynamic>[],
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
      expect(requestCount, 2);
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
          '/api/v2/outlets/list' => [
            {'id': 'outlet-1'},
          ],
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

  test(
    'login posts OpenAPI credentials and uses returned access token',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      Map<String, dynamic>? loginBody;
      var authorization = '';
      final serverSubscription = server.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        if (request.method == 'POST' && request.uri.path == '/api/v2/login') {
          loginBody = jsonDecode(
            await utf8.decoder.bind(request).join(),
          ) as Map<String, dynamic>;
          request.response.write(
            jsonEncode({
              'is_success': true,
              'status_code': 200,
              'message': null,
              'data': {
                'id': 7,
                'name': 'Test User',
                'email': 'staff@example.com',
                'access_token': 'api-issued-session-token',
              },
              'errors': null,
            }),
          );
        } else {
          authorization =
              request.headers.value(HttpHeaders.authorizationHeader) ?? '';
          request.response.write(
            jsonEncode({
              'is_success': true,
              'status_code': 200,
              'data': request.uri.path == '/api/v2/outlets/list'
                  ? [
                      {'id': 'outlet-1'},
                    ]
                  : <dynamic>[],
              'paginator': {'total': 0},
            }),
          );
        }
        await request.response.close();
      });
      final api = PosApiService(baseUrl: 'http://127.0.0.1:${server.port}/api');

      try {
        final user = await api.login(
          email: ' staff@example.com ',
          password: 'test-password',
          licenseKey: ' license-123 ',
        );
        await api.getSales();

        expect(user.name, 'Test User');
        expect(user.email, 'staff@example.com');
        expect(loginBody, {
          'email': 'staff@example.com',
          'password': 'test-password',
          'license_key': 'license-123',
        });
        expect(authorization, 'Bearer api-issued-session-token');
      } finally {
        api.close();
        await serverSubscription.cancel();
        await server.close(force: true);
      }
    },
  );
}
