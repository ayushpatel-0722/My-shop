/// Defensive casting helpers for Firestore / JSON payloads.
///
/// Firestore documents are `Map<String, dynamic>` and a single mistyped field
/// (a number saved as a string, a missing list) used to crash `fromMap` with
/// a `NoSuchMethodError` deep inside a StreamBuilder. Every model now parses
/// through these helpers so a bad document degrades to a default value.
library;

import 'dart:convert';

/// Reads [value] as [double]; accepts `num` and numeric strings.
double asDouble(dynamic value, [double fallback = 0]) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim()) ?? fallback;
  return fallback;
}

/// Reads [value] as [int]; accepts `num` and numeric strings.
int asInt(dynamic value, [int fallback = 0]) {
  if (value == null) return fallback;
  if (value is num) return value.toInt();
  if (value is String) {
    return int.tryParse(value.trim()) ??
        (double.tryParse(value.trim())?.toInt() ?? fallback);
  }
  return fallback;
}

/// Reads [value] as a non-null [String].
String asString(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  if (value is String) return value;
  return value.toString();
}

/// Reads [value] as [bool]; accepts the strings "true"/"1"/"yes".
bool asBool(dynamic value, [bool fallback = false]) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final v = value.trim().toLowerCase();
    if (v == 'true' || v == '1' || v == 'yes') return true;
    if (v == 'false' || v == '0' || v == 'no') return false;
  }
  return fallback;
}

/// Reads [value] as `List<String>`, dropping nulls and empty entries.
/// Accepts Iterable, single String, or JSON-encoded array string.
List<String> asStringList(dynamic value) {
  if (value == null) return const <String>[];
  if (value is String) {
    final v = value.trim();
    if (v.isEmpty) return const <String>[];
    if (v.startsWith('[') && v.endsWith(']')) {
      try {
        final decoded = jsonDecode(v);
        if (decoded is Iterable) {
          return decoded
              .map((e) => e?.toString().trim() ?? '')
              .where((e) => e.isNotEmpty)
              .toList(growable: false);
        }
      } catch (_) {}
    }
    return [v];
  }
  if (value is Iterable) {
    return value
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }
  return const <String>[];
}

/// Reads [value] as `List<Map<String, dynamic>>`.
List<Map<String, dynamic>> asMapList(dynamic value) {
  if (value is! Iterable) return const <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}

/// Reads [value] as `Map<String, int>`.
Map<String, int> asIntMap(dynamic value) {
  if (value is! Map) return const <String, int>{};
  final out = <String, int>{};
  value.forEach((key, val) {
    final parsed = asInt(val, 0);
    if (parsed > 0) out[key.toString()] = parsed;
  });
  return out;
}

/// Reads [value] as `Map<String, String>`.
Map<String, String> asStringMap(dynamic value) {
  if (value is! Map) return const <String, String>{};
  return value.map(
    (key, val) => MapEntry(key.toString(), val?.toString() ?? ''),
  );
}

/// Parses an ISO-8601 string (or an int epoch) into a [DateTime].
DateTime? asDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value.trim());
  }
  return null;
}

/// True when [value] is an absolute http(s) URL.
bool isHttpUrl(String value) {
  final v = value.trim().toLowerCase();
  return v.startsWith('http://') || v.startsWith('https://');
}

/// Truncates [id] for compact order / document chips without ever throwing.
String shortId(String id, [int length = 6]) {
  if (id.isEmpty) return '—';
  if (id.length <= length) return id.toUpperCase();
  return id.substring(0, length).toUpperCase();
}
