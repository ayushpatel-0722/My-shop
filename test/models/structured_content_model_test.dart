import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/models/product.dart';

/// A1 — structured content models.
///
/// `highlights:[{id,title,value,order}]` and
/// `allDetails:[{id,title,type:"text"|"keyValue",text|items:[...],order}]`
/// must round-trip through fromMap/toMap null-safely and sort by `order`.
void main() {
  group('HighlightItem', () {
    test('fromMap is null-safe on missing fields', () {
      final h = HighlightItem.fromMap(const {});
      expect(h.id, '');
      expect(h.title, '');
      expect(h.value, '');
      expect(h.order, 0);
      expect(h.isEmpty, isTrue);
    });

    test('toMap/fromMap round-trips', () {
      const h = HighlightItem(id: 'h1', title: 'RAM', value: '8 GB', order: 3);
      final back = HighlightItem.fromMap(h.toMap());
      expect(back.id, 'h1');
      expect(back.title, 'RAM');
      expect(back.value, '8 GB');
      expect(back.order, 3);
    });

    test('completeness rules match the migration contract', () {
      const valueOnly = HighlightItem(title: '', value: '500g glass jar');
      const halfWritten = HighlightItem(title: 'Net', value: '');
      const full = HighlightItem(title: 'Net', value: '500g');

      expect(valueOnly.isUsable, isTrue, reason: 'legacy rows are value-only');
      expect(valueOnly.isHalfWritten, isFalse);
      expect(valueOnly.isComplete, isFalse);

      expect(halfWritten.isUsable, isFalse);
      expect(halfWritten.isHalfWritten, isTrue);

      expect(full.isUsable, isTrue);
      expect(full.isComplete, isTrue);
    });
  });

  group('DetailItem', () {
    test('fromMap is null-safe', () {
      final d = DetailItem.fromMap(const {'title': 'Shelf Life'});
      expect(d.title, 'Shelf Life');
      expect(d.value, '');
      expect(d.order, 0);
      expect(d.isComplete, isFalse);
    });

    test('round-trips', () {
      const d = DetailItem(
        id: 'd1',
        title: 'Fabric',
        value: 'Cotton',
        order: 1,
      );
      final back = DetailItem.fromMap(d.toMap());
      expect(back.id, 'd1');
      expect(back.title, 'Fabric');
      expect(back.value, 'Cotton');
      expect(back.order, 1);
      expect(back.isComplete, isTrue);
    });
  });

  group('DetailSection', () {
    test('fromMap is null-safe and defaults to text type', () {
      final s = DetailSection.fromMap(const {});
      expect(s.title, '');
      expect(s.type, DetailSectionType.text);
      expect(s.text, '');
      expect(s.items, isEmpty);
      expect(s.isEmptyContent, isTrue);
    });

    test('unknown type falls back to text and is flagged invalid', () {
      final s = DetailSection.fromMap(const {'title': 'X', 'type': 'table'});
      expect(s.type, DetailSectionType.text, reason: 'invalid types degrade');
      expect(DetailSectionType.isValid('table'), isFalse);
    });

    test('text sections round-trip with their text', () {
      const s = DetailSection(
        id: 's1',
        title: 'Description',
        type: DetailSectionType.text,
        text: 'Organic wild bee honey',
        order: 0,
      );
      final back = DetailSection.fromMap(s.toMap());
      expect(back.title, 'Description');
      expect(back.isText, isTrue);
      expect(back.isKeyValue, isFalse);
      expect(back.text, 'Organic wild bee honey');
      expect(back.order, 0);
    });

    test('keyValue sections round-trip with their items', () {
      const s = DetailSection(
        id: 's2',
        title: 'Specifications',
        type: DetailSectionType.keyValue,
        items: [
          DetailItem(title: 'Shelf Life', value: '6 Months'),
          DetailItem(title: 'Fabric', value: 'Cotton'),
        ],
        order: 1,
      );
      final back = DetailSection.fromMap(s.toMap());
      expect(back.isKeyValue, isTrue);
      expect(back.items.length, 2);
      expect(back.items.first.title, 'Shelf Life');
      expect(back.items.last.value, 'Cotton');
    });

    test('fromMap survives a null items list', () {
      final s = DetailSection.fromMap(const {
        'title': 'Specs',
        'type': 'keyValue',
        'items': null,
      });
      expect(s.items, isEmpty);
    });
  });

  group('Product content ordering', () {
    test('sortedHighlights / sortedAllDetails sort by order', () {
      const p = Product(
        id: 'p1',
        companyId: 'c',
        categoryId: 'cat',
        name: 'P',
        highlights: [
          HighlightItem(title: 'Second', value: '2', order: 1),
          HighlightItem(title: 'First', value: '1', order: 0),
          HighlightItem(title: 'Third', value: '3', order: 2),
        ],
        allDetails: [
          DetailSection(
            title: 'B',
            type: DetailSectionType.text,
            text: 'b',
            order: 1,
          ),
          DetailSection(
            title: 'A',
            type: DetailSectionType.text,
            text: 'a',
            order: 0,
          ),
        ],
      );

      expect(p.sortedHighlights.map((h) => h.title), [
        'First',
        'Second',
        'Third',
      ]);
      expect(p.sortedAllDetails.map((s) => s.title), ['A', 'B']);
    });
  });
}
