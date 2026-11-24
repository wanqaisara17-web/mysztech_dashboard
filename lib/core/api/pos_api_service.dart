import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/inventory_movement.dart';
import '../models/inventory_stock.dart';
import '../models/item.dart';
import '../models/authenticated_user.dart';
import '../models/sales_page.dart';

const posApiProductionUrl = 'https://mysztech.com/api';
const posApiStagingUrl = 'https://mts-pos-staging.laravel.cloud/api';
// Use the live POS API in both debug and release builds.
const posApiBaseUrl = posApiProductionUrl;

class PosApiException implements Exception {
  const PosApiException(
    this.message, {
    this.statusCode,
    this.requiresToken = false,
  });

  final String message;
  final int? statusCode;
  final bool requiresToken;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

class PosApiService {
  PosApiService({
    HttpClient? client,
    this.baseUrl = posApiBaseUrl,
    String? token,
  }) : _client = client ?? HttpClient(),
       _token = token ?? '';

  final HttpClient _client;
  final String baseUrl;
  String _token;
  Future<SalesPage>? _salesRequest;
  Future<List<PosItem>>? _itemsRequest;
  Future<List<InventoryStock>>? _inventoryRequest;
  Future<List<InventoryMovement>>? _movementsRequest;
  final Map<String, Future<String?>> _categoryNames = {};
  static const requestTimeout = Duration(seconds: 20);

  void setToken(String value) {
    final cleaned = value
        .trim()
        .replaceFirst(RegExp(r'^Bearer\s+', caseSensitive: false), '')
        .trim();
    _token = cleaned;
    _salesRequest = null;
    _itemsRequest = null;
    _inventoryRequest = null;
    _movementsRequest = null;
    _categoryNames.clear();
  }

  Future<AuthenticatedUser> login({
    required String email,
    required String password,
    required String licenseKey,
  }) async {
    try {
      final request = await _client
          .postUrl(Uri.parse('$baseUrl/v2/login'))
          .timeout(requestTimeout);
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.write(
        jsonEncode({
          'email': email.trim(),
          'password': password,
          'license_key': licenseKey.trim(),
        }),
      );
      final response = await request.close().timeout(requestTimeout);
      final body = await utf8.decoder
          .bind(response)
          .join()
          .timeout(requestTimeout);
      Map<String, dynamic>? decoded;
      try {
        final value = jsonDecode(body);
        if (value is Map<String, dynamic>) decoded = value;
      } on FormatException {
        decoded = null;
      }

      final statusCode = decoded?['status_code'];
      final apiStatus = statusCode is int
          ? statusCode
          : int.tryParse('$statusCode');
      final effectiveStatus = apiStatus ?? response.statusCode;
      if (effectiveStatus == HttpStatus.unauthorized) {
        throw const PosApiException(
          'Email, password, or license key was not accepted.',
          statusCode: HttpStatus.unauthorized,
        );
      }
      if (effectiveStatus == HttpStatus.forbidden) {
        throw const PosApiException(
          'This account is not permitted to sign in to the staging service.',
          statusCode: HttpStatus.forbidden,
        );
      }
      if (effectiveStatus == HttpStatus.unprocessableEntity) {
        throw const PosApiException(
          'Check the email, password, and license key, then try again.',
          statusCode: HttpStatus.unprocessableEntity,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw PosApiException(
          'The sign-in service returned HTTP ${response.statusCode}.',
          statusCode: response.statusCode,
        );
      }
      if (decoded == null ||
          decoded['is_success'] != true ||
          apiStatus != 200) {
        throw const PosApiException(
          'The sign-in service returned an unreadable or unsuccessful response.',
        );
      }
      final data = decoded['data'];
      if (data is! Map<String, dynamic>) {
        throw const PosApiException(
          'The sign-in response did not include a user session.',
        );
      }
      final accessToken = data['access_token'];
      if (accessToken is! String || accessToken.trim().isEmpty) {
        throw const PosApiException(
          'The sign-in response did not include an access token.',
        );
      }
      setToken(accessToken);
      return AuthenticatedUser(
        name: data['name']?.toString() ?? 'User',
        email: data['email']?.toString(),
      );
    } on PosApiException {
      rethrow;
    } on TimeoutException {
      throw const PosApiException(
        'Sign-in timed out. Check your connection and retry.',
      );
    } on SocketException {
      throw const PosApiException(
        'Could not reach the staging sign-in service. Check your connection.',
      );
    } on HttpException {
      throw const PosApiException(
        'The staging sign-in connection was interrupted. Retry.',
      );
    } on IOException {
      throw const PosApiException(
        'A network error interrupted sign-in. Retry when connected.',
      );
    } on FormatException {
      throw const PosApiException('The sign-in response could not be read.');
    }
  }

  Future<SalesPage> getSales({bool forceRefresh = false}) {
    if (forceRefresh || _salesRequest == null) {
      _salesRequest = _loadSales();
    }
    return _salesRequest!;
  }

  Future<List<PosItem>> getItems({bool forceRefresh = false}) {
    if (forceRefresh || _itemsRequest == null) {
      _itemsRequest = _loadItems();
    }
    return _itemsRequest!;
  }

  Future<PosItem> getItem(String id) async {
    final document = await _getDocument('/v2/items/${Uri.encodeComponent(id)}');
    final data = document['data'];
    if (data is! Map<String, dynamic>) {
      throw const PosApiException(
        'The item detail response did not contain an item.',
      );
    }
    final item = PosItem.fromJson(data);
    final categoryName = await _categoryName(item.categoryId);
    return item.withCategory(categoryName);
  }

  Future<List<InventoryStock>> getInventoryStock({bool forceRefresh = false}) {
    if (forceRefresh || _inventoryRequest == null) {
      _inventoryRequest = _loadInventoryStock();
    }
    return _inventoryRequest!;
  }

  Future<List<InventoryMovement>> getInventoryMovements({
    bool forceRefresh = false,
  }) {
    if (forceRefresh || _movementsRequest == null) {
      _movementsRequest = _loadInventoryMovements();
    }
    return _movementsRequest!;
  }

  Future<List<PosItem>> _loadItems() async {
    final rows = await _getList('/v2/items/list');
    final items = rows.map(PosItem.fromJson).toList(growable: false);
    return Future.wait(
      items.map((item) async {
        final categoryName = await _categoryName(item.categoryId);
        return item.withCategory(categoryName);
      }),
    );
  }

  Future<List<InventoryStock>> _loadInventoryStock() async {
    final rowsFuture = _getList('/v2/inventory-outlet/list');
    final itemsFuture = getItems()
        .then<List<PosItem>>((items) => items)
        .catchError((Object _) => <PosItem>[]);
    final results = await Future.wait<Object>([rowsFuture, itemsFuture]);
    final rows = results[0] as List<Map<String, dynamic>>;
    final items = results[1] as List<PosItem>;
    final namesByInventoryId = <String, String>{
      for (final item in items)
        if (item.inventoryId != null) item.inventoryId!: item.name,
    };
    return rows
        .map((row) {
          final id = row['inventory_id']?.toString() ?? '';
          return InventoryStock.fromJson(
            row,
            itemName: namesByInventoryId[id] ?? 'Inventory $id',
          );
        })
        .toList(growable: false);
  }

  Future<List<InventoryMovement>> _loadInventoryMovements() async =>
      (await _getList('/v2/inventory-transactions/list'))
          .map(InventoryMovement.fromJson)
          .toList(growable: false);

  Future<String?> _categoryName(String? id) {
    if (id == null || id.isEmpty) return Future.value(null);
    return _categoryNames.putIfAbsent(id, () async {
      try {
        final document = await _getDocument(
          '/v2/categories/${Uri.encodeComponent(id)}',
        );
        final data = document['data'];
        return data is Map<String, dynamic> ? data['name']?.toString() : null;
      } on PosApiException {
        return null;
      }
    });
  }

  Future<List<Map<String, dynamic>>> _getList(String path) async {
    final document = await _getDocument(path);
    final data = document['data'];
    if (data is! List) {
      throw PosApiException(
        'The ${_endpointName(path)} response did not contain a list.',
      );
    }
    return data.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  Future<Map<String, dynamic>> _getDocument(String path) async {
    if (_token.isEmpty) {
      throw const PosApiException(
        'Connect an authorized staging token from Sales to load this data.',
        requiresToken: true,
      );
    }
    try {
      final request = await _client
          .getUrl(Uri.parse('$baseUrl$path'))
          .timeout(requestTimeout);
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_token');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(requestTimeout);
      final body = await utf8.decoder
          .bind(response)
          .join()
          .timeout(requestTimeout);
      if (response.statusCode == HttpStatus.unauthorized) {
        throw const PosApiException(
          'Your token was rejected. Supply a currently authorized staging token.',
          statusCode: HttpStatus.unauthorized,
        );
      }
      if (response.statusCode == HttpStatus.forbidden) {
        throw PosApiException(
          'This staging account is not permitted to access ${_endpointName(path)}.',
          statusCode: HttpStatus.forbidden,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw PosApiException(
          'The ${_endpointName(path)} service returned HTTP ${response.statusCode}.',
          statusCode: response.statusCode,
        );
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw PosApiException(
          'The ${_endpointName(path)} response was not a JSON object.',
        );
      }
      final statusCode = decoded['status_code'];
      if (decoded['is_success'] != true || statusCode != 200) {
        final code = statusCode is int
            ? statusCode
            : int.tryParse('$statusCode');
        if (code == HttpStatus.unauthorized || code == HttpStatus.forbidden) {
          throw PosApiException(
            code == HttpStatus.unauthorized
                ? 'Your token was rejected. Supply a currently authorized staging token.'
                : 'This staging account is not permitted to access ${_endpointName(path)}.',
            statusCode: code,
          );
        }
        throw PosApiException(
          decoded['message']?.toString() ??
              'The ${_endpointName(path)} service reported an error.',
          statusCode: code,
        );
      }
      return decoded;
    } on PosApiException {
      rethrow;
    } on TimeoutException {
      throw PosApiException(
        'The ${_endpointName(path)} request timed out. Retry when connected.',
      );
    } on SocketException {
      throw const PosApiException(
        'Could not reach the staging API. Check your connection and retry.',
      );
    } on HttpException {
      throw const PosApiException(
        'The staging API connection was interrupted. Retry the request.',
      );
    } on IOException {
      throw const PosApiException(
        'A network connection error interrupted the request. Retry when connected.',
      );
    } on FormatException {
      throw PosApiException(
        'The ${_endpointName(path)} response could not be read as JSON.',
      );
    }
  }

  String _endpointName(String path) => switch (path) {
    '/v2/items/list' => 'items',
    '/v2/inventory-outlet/list' => 'inventory',
    '/v2/inventory-transactions/list' => 'inventory movements',
    _ when path.startsWith('/v2/items/') => 'item details',
    _ when path.startsWith('/v2/categories/') => 'item category',
    _ => 'staging API',
  };

  Future<SalesPage> _loadSales() async {
    debugPrint(
      '[Sales API] request starting: token present=${_token.isNotEmpty}',
    );
    if (_token.isEmpty) {
      throw const PosApiException(
        'Enter an authorized staging token to load sales. It stays in memory for this app session.',
        requiresToken: true,
      );
    }

    try {
      final uri = Uri.parse('$baseUrl/v2/sales/list');
      final request = await _client.getUrl(uri).timeout(requestTimeout);
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_token');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(requestTimeout);
      debugPrint(
        '[Sales API] GET /v2/sales/list status=${response.statusCode}',
      );
      final body = await utf8.decoder
          .bind(response)
          .join()
          .timeout(requestTimeout);

      if (response.statusCode == HttpStatus.unauthorized) {
        throw const PosApiException(
          'Your token was rejected. Supply a currently authorized staging token.',
          statusCode: HttpStatus.unauthorized,
        );
      }
      if (response.statusCode == HttpStatus.forbidden) {
        throw const PosApiException(
          'This staging account is not permitted to view sales. Ask an administrator to grant access.',
          statusCode: HttpStatus.forbidden,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw PosApiException(
          'The sales service returned HTTP ${response.statusCode}.',
          statusCode: response.statusCode,
        );
      }

      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const PosApiException(
          'The sales response was not a JSON object.',
        );
      }
      if (decoded['is_success'] != true || decoded['status_code'] != 200) {
        throw PosApiException(
          decoded['message']?.toString() ??
              'The API did not report a successful response.',
          statusCode: decoded['status_code'] is int
              ? decoded['status_code'] as int
              : null,
        );
      }
      return SalesPage.fromJson(decoded);
    } on PosApiException {
      rethrow;
    } on TimeoutException {
      throw const PosApiException(
        'The sales request timed out. Check your connection and retry.',
      );
    } on SocketException {
      debugPrint('[Sales API] error category=network_unreachable');
      throw const PosApiException(
        'Could not reach the staging API. Check your connection and retry.',
      );
    } on HttpException {
      debugPrint('[Sales API] error category=http_connection');
      throw const PosApiException(
        'The connection to the staging API was interrupted. Retry the request.',
      );
    } on IOException {
      debugPrint('[Sales API] error category=io');
      throw const PosApiException(
        'A network connection error interrupted the sales request. Retry when connected.',
      );
    } on FormatException {
      debugPrint('[Sales API] error category=response_format');
      throw const PosApiException(
        'The sales response could not be read as valid JSON.',
      );
    } catch (_) {
      debugPrint('[Sales API] error category=unexpected');
      rethrow;
    }
  }

  void close() => _client.close(force: true);
}
