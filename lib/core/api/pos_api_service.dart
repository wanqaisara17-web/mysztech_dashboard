import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/inventory_movement.dart';
import '../models/inventory_stock.dart';
import '../models/item.dart';
import '../models/authenticated_user.dart';
import '../models/sales_page.dart';
import '../models/outlet.dart';
import '../models/sales_history.dart';
import '../models/sale.dart';

const posApiProductionUrl = 'https://mysztech.com/api';
const posApiBaseUrl = posApiProductionUrl;

typedef InventoryRetrievedCallback = Future<void> Function(
  String outletId,
  List<InventoryStock> inventory,
);

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
  final Map<String, Future<SalesPage>> _salesRequests = {};
  Future<List<Outlet>>? _outletsRequest;
  String? _selectedOutletId;
  Future<List<PosItem>>? _itemsRequest;
  Future<List<InventoryStock>>? _inventoryRequest;
  Future<List<InventoryMovement>>? _movementsRequest;
  final Map<String, Future<String?>> _categoryNames = {};
  InventoryRetrievedCallback? onInventoryRetrieved;
  static const requestTimeout = Duration(seconds: 20);

  String? get selectedOutletId => _selectedOutletId;

  void selectOutlet(String outletId) {
    if (_selectedOutletId == outletId) return;
    _selectedOutletId = outletId;
    _salesRequests.clear();
    _itemsRequest = null;
    _inventoryRequest = null;
    _movementsRequest = null;
    _categoryNames.clear();
  }

  void setToken(String value) {
    final cleaned = value
        .trim()
        .replaceFirst(RegExp(r'^Bearer\s+', caseSensitive: false), '')
        .trim();
    _token = cleaned;
    _salesRequests.clear();
    _outletsRequest = null;
    _selectedOutletId = null;
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
          'This account is not permitted to sign in to the production service.',
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
        accountId: data['id']?.toString(),
      );
    } on PosApiException {
      rethrow;
    } on TimeoutException {
      throw const PosApiException(
        'Sign-in timed out. Check your connection and retry.',
      );
    } on SocketException {
      throw const PosApiException(
        'Could not reach the production sign-in service. Check your connection.',
      );
    } on HttpException {
      throw const PosApiException(
        'The production sign-in connection was interrupted. Retry.',
      );
    } on IOException {
      throw const PosApiException(
        'A network error interrupted sign-in. Retry when connected.',
      );
    } on FormatException {
      throw const PosApiException('The sign-in response could not be read.');
    }
  }

  Future<SalesPage> getSales({
    bool forceRefresh = false,
    int page = 1,
    String? outletId,
  }) async {
    final selected = outletId ?? await _effectiveOutletId();
    final key = '$selected:$page';
    if (forceRefresh || !_salesRequests.containsKey(key)) {
      _salesRequests[key] = _loadSales(page: page, outletId: selected);
    }
    return _salesRequests[key]!;
  }

  Future<List<Outlet>> getOutlets({bool forceRefresh = false}) {
    if (forceRefresh || _outletsRequest == null) {
      _outletsRequest = _loadOutlets();
    }
    return _outletsRequest!;
  }

  Future<SalesHistory> getCompleteSalesHistory({String? outletId}) async {
    final selected = outletId ?? await _effectiveOutletId();
    final first = await getSales(page: 1, outletId: selected);
    final byId = <String, Sale>{};
    void add(SalesPage page) {
      for (final sale in page.sales) {
        final key = sale.id.isNotEmpty ? sale.id : (sale.showUuid ?? '');
        if (key.isNotEmpty) byId.putIfAbsent(key, () => sale);
      }
    }

    add(first);
    var complete =
        (first.lastPage == 1 &&
            (first.total == null || byId.length >= first.total!)) ||
        (first.total != null && byId.length >= first.total!);
    Object? error;
    final lastPage = first.lastPage;
    if (!complete && lastPage != null && lastPage > 1) {
      for (var pageNumber = 2; pageNumber <= lastPage; pageNumber++) {
        try {
          final before = byId.length;
          final nextPage = await getSales(page: pageNumber, outletId: selected);
          add(nextPage);
          if (byId.length == before &&
              (first.total == null || byId.length < first.total!)) {
            error = const FormatException(
              'The API did not return new receipt records for the requested page.',
            );
            break;
          }
        } catch (caught) {
          error = caught;
          break;
        }
      }
      complete = error == null && byId.length >= (first.total ?? byId.length);
    }
    return SalesHistory(
      sales: byId.values.toList(growable: false),
      total: first.total,
      isComplete: complete,
      error: error,
    );
  }

  Future<String> _effectiveOutletId() async {
    if (_selectedOutletId case final selected?) return selected;
    final outlets = await getOutlets();
    if (outlets.isEmpty) {
      throw const PosApiException(
        'No accessible outlet was found for this account.',
      );
    }
    _selectedOutletId = outlets.first.id;
    return _selectedOutletId!;
  }

  Future<List<Outlet>> _loadOutlets() async {
    final first = await _getListPage('/v2/outlets/list', 1);
    final rows = [...first.rows];
    final seenIds = rows
        .map((row) => row['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    final lastPage = first.lastPage;
    if (lastPage != null && lastPage > 1) {
      for (var page = 2; page <= lastPage; page++) {
        try {
          final nextRows = (await _getListPage('/v2/outlets/list', page)).rows;
          final newRows = nextRows.where((row) {
            final id = row['id']?.toString() ?? '';
            return id.isEmpty || seenIds.add(id);
          }).toList();
          if (newRows.isEmpty) break;
          rows.addAll(newRows);
        } on PosApiException {
          break;
        }
      }
    }
    final unique = <String, Outlet>{};
    for (final row in rows) {
      final outlet = Outlet.fromJson(row);
      if (outlet.id.isNotEmpty) unique[outlet.id] = outlet;
    }
    return unique.values.toList(growable: false);
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
    final outletId = await _effectiveOutletId();
    final rowsFuture = _getAllList(
      '/v2/inventory-outlet/list',
      outletId: outletId,
    );
    final itemsFuture = getItems()
        .then<List<PosItem>>((items) => items)
        .catchError((Object _) => <PosItem>[]);
    final results = await Future.wait<Object>([rowsFuture, itemsFuture]);
    final pagedRows = results[0] as _PagedRows;
    final rows = pagedRows.rows;
    final items = results[1] as List<PosItem>;
    final namesByInventoryId = <String, String>{
      for (final item in items)
        if (item.inventoryId != null) item.inventoryId!: item.name,
    };
    final stock = rows
        .map((row) {
          final id = row['inventory_id']?.toString() ?? '';
          return InventoryStock.fromJson(
            row,
            itemName: namesByInventoryId[id] ?? 'Inventory $id',
          );
        })
        .toList(growable: false);
    final callback = onInventoryRetrieved;
    if (pagedRows.isComplete &&
        _selectedOutletId == outletId &&
        callback != null) {
      unawaited(
        Future<void>.sync(() => callback(outletId, stock))
            .catchError((Object _) {}),
      );
    }
    return stock;
  }

  Future<List<InventoryMovement>> _loadInventoryMovements() async {
    final results = await Future.wait<Object>([
      _getList('/v2/inventory-transactions/list'),
      getItems()
          .then<List<PosItem>>((items) => items)
          .catchError((Object _) => <PosItem>[]),
    ]);
    final rows = results[0] as List<Map<String, dynamic>>;
    final items = results[1] as List<PosItem>;
    final namesByInventoryId = <String, String>{
      for (final item in items)
        if (item.inventoryId != null) item.inventoryId!: item.name,
    };
    return rows
        .map((row) {
          final movement = InventoryMovement.fromJson(row);
          return movement.withName(
            movement.name?.isNotEmpty == true
                ? movement.name
                : namesByInventoryId[movement.inventoryId],
          );
        })
        .toList(growable: false);
  }

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
    return (await _getListPage(path, 1)).rows;
  }

  Future<_PagedRows> _getAllList(
    String path, {
    required String outletId,
  }) async {
    final first = await _getListPage(path, 1, outletId: outletId);
    final rows = [...first.rows];
    final seen = <String>{
      for (final row in rows)
        if ((row['inventory_id']?.toString() ?? '').isNotEmpty)
          row['inventory_id'].toString(),
    };
    final lastPage = first.lastPage;
    final total = first.total;
    if (lastPage == null) {
      return _PagedRows(
        rows: rows,
        isComplete: total != null && rows.length >= total,
      );
    }
    if (lastPage <= 1) {
      return _PagedRows(
        rows: rows,
        isComplete: total == null || rows.length >= total,
      );
    }

    var isComplete = true;
    for (var page = 2; page <= lastPage; page++) {
      try {
        final next = await _getListPage(path, page, outletId: outletId);
        final newRows = next.rows
            .where((row) {
              final id = row['inventory_id']?.toString() ?? '';
              return id.isEmpty || seen.add(id);
            })
            .toList(growable: false);
        if (newRows.isEmpty && next.rows.isNotEmpty) {
          isComplete = false;
          break;
        }
        rows.addAll(newRows);
      } on PosApiException {
        isComplete = false;
        break;
      }
    }
    if (total != null && rows.length < total) isComplete = false;
    return _PagedRows(rows: rows, isComplete: isComplete);
  }

  Future<({List<Map<String, dynamic>> rows, int? lastPage, int? total})>
  _getListPage(String path, int page, {String? outletId}) async {
    final document = await _getDocument(
      page == 1 ? path : '$path?page=$page',
      useOutletHeader: path != '/v2/outlets/list',
      outletId: outletId,
    );
    final data = document['data'];
    if (data is! List) {
      throw PosApiException(
        'The ${_endpointName(path)} response did not contain a list.',
      );
    }
    final paginator = document['paginator'];
    final rawLastPage = paginator is Map<String, dynamic>
        ? paginator['lastPage']
        : null;
    final lastPage = rawLastPage is int
        ? rawLastPage
        : int.tryParse('$rawLastPage');
    final rawTotal = paginator is Map<String, dynamic>
        ? paginator['total']
        : null;
    final total = rawTotal is int ? rawTotal : int.tryParse('$rawTotal');
    return (
      rows: data.whereType<Map<String, dynamic>>().toList(growable: false),
      lastPage: lastPage,
      total: total,
    );
  }

  Future<Map<String, dynamic>> _getDocument(
    String path, {
    bool useOutletHeader = true,
    String? outletId,
  }) async {
    if (_token.isEmpty) {
      throw const PosApiException(
        'Connect an authorized production token from Sales to load this data.',
        requiresToken: true,
      );
    }
    try {
      final request = await _client
          .getUrl(Uri.parse('$baseUrl$path'))
          .timeout(requestTimeout);
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_token');
      if (useOutletHeader) {
        request.headers.set(
          'outlet-id',
          outletId ?? await _effectiveOutletId(),
        );
      }
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(requestTimeout);
      final body = await utf8.decoder
          .bind(response)
          .join()
          .timeout(requestTimeout);
      if (response.statusCode == HttpStatus.unauthorized) {
        throw const PosApiException(
          'Your token was rejected. Supply a currently authorized production token.',
          statusCode: HttpStatus.unauthorized,
        );
      }
      if (response.statusCode == HttpStatus.forbidden) {
        throw PosApiException(
          'This production account is not permitted to access ${_endpointName(path)}.',
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
                ? 'Your token was rejected. Supply a currently authorized production token.'
                : 'This production account is not permitted to access ${_endpointName(path)}.',
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
        'Could not reach the production API. Check your connection and retry.',
      );
    } on HttpException {
      throw const PosApiException(
        'The production API connection was interrupted. Retry the request.',
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
    _ => 'production API',
  };

  Future<SalesPage> _loadSales({
    required int page,
    required String outletId,
  }) async {
    debugPrint(
      '[Sales API] request starting: token present=${_token.isNotEmpty}',
    );
    if (_token.isEmpty) {
      throw const PosApiException(
        'Enter an authorized production token to load sales. It stays in memory for this app session.',
        requiresToken: true,
      );
    }

    try {
      final uri = Uri.parse('$baseUrl/v2/receipts/list?page=$page');
      final request = await _client.getUrl(uri).timeout(requestTimeout);
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_token');
      request.headers.set('outlet-id', outletId);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(requestTimeout);
      debugPrint(
        '[Sales API] GET /v2/receipts/list status=${response.statusCode}',
      );
      final body = await utf8.decoder
          .bind(response)
          .join()
          .timeout(requestTimeout);

      if (response.statusCode == HttpStatus.unauthorized) {
        throw const PosApiException(
          'Your token was rejected. Supply a currently authorized production token.',
          statusCode: HttpStatus.unauthorized,
        );
      }
      if (response.statusCode == HttpStatus.forbidden) {
        throw const PosApiException(
          'This production account is not permitted to view sales. Ask an administrator to grant access.',
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
        'Could not reach the production API. Check your connection and retry.',
      );
    } on HttpException {
      debugPrint('[Sales API] error category=http_connection');
      throw const PosApiException(
        'The connection to the production API was interrupted. Retry the request.',
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

class _PagedRows {
  const _PagedRows({required this.rows, required this.isComplete});

  final List<Map<String, dynamic>> rows;
  final bool isComplete;
}
