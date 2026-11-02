import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter_test/flutter_test.dart';

/// The product-review strings exist in English, Hindi and Gujarati, are really
/// translated, and keep the same {placeholders}.
void main() {
  Map<String, dynamic> load(String code) =>
      jsonDecode(File('lib/app/l10n/app_$code.arb').readAsStringSync())
          as Map<String, dynamic>;

  final en = load('en');
  final hi = load('hi');
  final gu = load('gu');

  const keys = [
    'reviewRateProductTitle',
    'reviewEditTitle',
    'reviewYourRating',
    'reviewMessageLabel',
    'reviewSubmitButton',
    'reviewUpdateButton',
    'reviewThanks',
    'reviewUpdated',
    'reviewCouldNotSubmit',
    'reviewSignInRequired',
    'reviewOnlyAfterDelivery',
    'reviewOrderNotFound',
    'reviewNotYourOrder',
    'reviewItemNotInOrder',
    'reviewRateYourItems',
    'reviewWrite',
    'reviewEdit',
    'reviewCouldNotLoad',
    'productNoReviewsYet',
    'productRatingsAndReviews',
  ];

  Set<String> placeholders(String text) => RegExp(
    r'\{(\w+)(?:,|\})',
  ).allMatches(text).map((m) => m.group(1)!).toSet();

  for (final entry in {'Hindi': hi, 'Gujarati': gu}.entries) {
    final arb = entry.value;
    test('${entry.key} has every review string, translated', () {
      for (final k in keys) {
        final v = arb[k];
        expect(v, isA<String>(), reason: '$k missing');
        expect((v as String).trim(), isNotEmpty, reason: '$k empty');
        expect(v, isNot(en[k]), reason: '$k is not translated');
      }
    });

    test('${entry.key} keeps the same {placeholders}', () {
      for (final k in keys) {
        expect(
          setEquals(
            placeholders(en[k] as String),
            placeholders(arb[k] as String),
          ),
          isTrue,
          reason: k,
        );
      }
    });
  }

  test('placeholders are declared in the English metadata', () {
    for (final k in keys) {
      final used = placeholders(en[k] as String);
      if (used.isEmpty) continue;
      final declared =
          (((en['@$k'] as Map?)?['placeholders'] as Map?)?.keys ?? [])
              .map((e) => e.toString())
              .toSet();
      expect(setEquals(declared, used), isTrue, reason: k);
    }
  });
}
