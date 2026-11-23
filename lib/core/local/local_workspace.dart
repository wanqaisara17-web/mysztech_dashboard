import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/local_product.dart';

class LocalWorkspace extends ChangeNotifier {
  LocalWorkspace({MethodChannel? channel})
    : _channel =
          channel ??
          const MethodChannel('com.example.pos_monitoring_app/local_workspace');

  final MethodChannel _channel;
  final List<LocalProduct> _products = [];
  bool _loaded = false;
  bool _persistentStorageAvailable = false;
  Future<void>? _loading;

  List<LocalProduct> get products => List.unmodifiable(_products);
  bool get isLoaded => _loaded;
  bool get persistentStorageAvailable => _persistentStorageAvailable;

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final encoded = await _channel.invokeMethod<String>('loadWorkspace');
      if (encoded != null && encoded.isNotEmpty) {
        final decoded = jsonDecode(encoded);
        if (decoded is List) {
          _products
            ..clear()
            ..addAll(
              decoded.whereType<Map<String, dynamic>>().map(
                LocalProduct.fromJson,
              ),
            );
        }
      }
      _persistentStorageAvailable = true;
    } on MissingPluginException {
      _persistentStorageAvailable = false;
    } on PlatformException {
      _persistentStorageAvailable = false;
    } on FormatException {
      _persistentStorageAvailable = true;
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> saveProduct(LocalProduct product) async {
    await load();
    _products.removeWhere((existing) => existing.id == product.id);
    _products.add(product);
    _products.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    notifyListeners();
    await _persist();
  }

  Future<void> deleteProduct(String id) async {
    await load();
    _products.removeWhere((product) => product.id == id);
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final saved = await _channel.invokeMethod<bool>('saveWorkspace', {
        'json': jsonEncode(
          _products.map((product) => product.toJson()).toList(),
        ),
      });
      _persistentStorageAvailable = saved ?? false;
    } on MissingPluginException {
      _persistentStorageAvailable = false;
    } on PlatformException {
      _persistentStorageAvailable = false;
    }
    notifyListeners();
  }
}
