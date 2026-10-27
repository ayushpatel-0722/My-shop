import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter_test/flutter_test.dart';

/// Every "Shop Settings" string exists in English, Hindi and Gujarati, is
/// really translated, and keeps the same {placeholders}.
void main() {
  Map<String, dynamic> load(String code) =>
      jsonDecode(File('lib/app/l10n/app_$code.arb').readAsStringSync())
          as Map<String, dynamic>;

  final en = load('en');
  final hi = load('hi');
  final gu = load('gu');
  final keys = en.keys
      .where((k) => k.startsWith('shop') && !k.startsWith('@'))
      .toList();

  Set<String> placeholders(String text) =>
      RegExp(r'\{(\w+)\}').allMatches(text).map((m) => m.group(1)!).toSet();

  test('there are shop strings to check', () {
    expect(keys.length, greaterThanOrEqualTo(60));
  });

  for (final entry in {'Hindi': hi, 'Gujarati': gu}.entries) {
    final lang = entry.key;
    final arb = entry.value;

    test('$lang has every shop string, non-empty', () {
      final missing = [
        for (final k in keys)
          if (arb[k] is! String || (arb[k] as String).trim().isEmpty) k,
      ];
      expect(missing, isEmpty);
    });

    test('$lang strings are translated, not copied from English', () {
      // Digits-only or symbol-only strings and a few shared words can match.
      const sameAllowed = {'shopMinutesInvalid'};
      final copied = [
        for (final k in keys)
          if (arb[k] == en[k] && !sameAllowed.contains(k)) k,
      ];
      expect(copied, isEmpty);
    });

    test('$lang keeps the same {placeholders} as English', () {
      final mismatched = [
        for (final k in keys)
          if (placeholders(
                en[k] as String,
              ).difference(placeholders((arb[k] ?? '') as String)).isNotEmpty ||
              placeholders(
                (arb[k] ?? '') as String,
              ).difference(placeholders(en[k] as String)).isNotEmpty)
            k,
      ];
      expect(mismatched, isEmpty);
    });
  }

  test('every English placeholder is declared in its @metadata', () {
    final undeclared = [
      for (final k in keys)
        if (placeholders(en[k] as String).isNotEmpty &&
            !setEquals(
              (((en['@$k'] as Map?)?['placeholders'] as Map?)?.keys ?? [])
                  .map((e) => e.toString())
                  .toSet(),
              placeholders(en[k] as String),
            ))
          k,
    ];
    expect(undeclared, isEmpty);
  });
}
