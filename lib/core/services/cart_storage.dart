import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/cart_item.dart';

/// Local database persistence service for shopping cart items.
///
/// Uses [SharedPreferences] to securely persist cart lines across app restarts,
/// preserving full product metadata, selected variants, quantities, and prices.
class CartStorage {
  static const String _cartStorageKey = 'local_cart_items_v1';

  final SharedPreferences? _prefs;

  CartStorage([this._prefs]);

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  /// Persists the current list of cart items to local storage.
  Future<void> saveCart(List<CartItem> items) async {
    try {
      final prefs = await _getPrefs();
      final list = items.map((e) => e.toMap()).toList();
      final rawJson = jsonEncode(list);
      await prefs.setString(_cartStorageKey, rawJson);
    } catch (e, st) {
      debugPrint('CartStorage.saveCart error: $e\n$st');
    }
  }

  /// Restores saved cart items from local storage.
  Future<List<CartItem>> loadCart() async {
    try {
      final prefs = await _getPrefs();
      final rawJson = prefs.getString(_cartStorageKey);
      if (rawJson == null || rawJson.trim().isEmpty) {
        return const [];
      }

      final decoded = jsonDecode(rawJson);
      if (decoded is! List) return const [];

      final items = <CartItem>[];
      for (final entry in decoded) {
        if (entry is Map<String, dynamic>) {
          items.add(CartItem.fromMap(entry));
        } else if (entry is Map) {
          items.add(CartItem.fromMap(Map<String, dynamic>.from(entry)));
        }
      }
      return items;
    } catch (e, st) {
      debugPrint('CartStorage.loadCart error: $e\n$st');
      return const [];
    }
  }

  /// Clears persisted cart items (e.g. after order placement or manual clear).
  Future<void> clearCart() async {
    try {
      final prefs = await _getPrefs();
      await prefs.remove(_cartStorageKey);
    } catch (e, st) {
      debugPrint('CartStorage.clearCart error: $e\n$st');
    }
  }
}
