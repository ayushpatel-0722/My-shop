import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/domain/addon_rules.dart';
import 'package:myshop/core/domain/cart_calculator.dart';
import 'package:myshop/core/domain/order_pricing.dart';
import 'package:myshop/core/models/cart_item.dart';
import 'package:myshop/core/models/order.dart';
import 'package:myshop/core/models/product.dart';
import 'package:myshop/core/models/product_addon.dart';
import 'package:myshop/core/services/cart_storage.dart';
import 'package:myshop/features/checkout/cart/cart_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Product add-ons: the selection rules, exact pricing, cart lines that stay
/// separate per combination, persistence and the order payload.
void main() {
  const delivery = ProductAddOn(
    id: 'ao_delivery',
    title: 'Delivery to floor',
    amount: 500,
  );
  const assembly = ProductAddOn(
    id: 'ao_assembly',
    title: 'Assembly',
    description: 'Fitted by our team',
    amount: 1000,
    discountAmt: 800,
  );
  const retired = ProductAddOn(
    id: 'ao_old',
    title: 'Old service',
    amount: 300,
    isActive: false,
  );

  Product bed({
    List<ProductAddOn> addOns = const [delivery, assembly, retired],
    String selection = AddOnSelectionType.checkbox,
  }) => Product(
    id: 'p_bed',
    companyId: 'c_wood',
    categoryId: 'cat_beds',
    name: 'Oak Bed',
    amount: 20000,
    discountAmt: 18000,
    stockQty: 5,
    addOns: addOns,
    addOnSelection: selection,
  );

  CartItem line(
    Product p, {
    List<String> ids = const [],
    int qty = 1,
    ProductVariant? variant,
  }) => CartItem.fromSelection(
    companyId: 'c_wood',
    companyName: 'Woodnest',
    product: p,
    selectedVariant: variant,
    qty: qty,
    addOns: AddOnRules.resolve(p, ids),
  );

  group('model', () {
    test('selection type defaults to checkbox, junk falls back to it', () {
      expect(
        const Product(id: 'x', companyId: 'c', name: 'n').addOnSelection,
        AddOnSelectionType.checkbox,
      );
      expect(
        Product.fromMap('x', {'addOnSelection': 'weird'}).addOnSelection,
        AddOnSelectionType.checkbox,
      );
      expect(
        Product.fromMap('x', {'addOnSelection': 'radio'}).addOnSelection,
        AddOnSelectionType.radio,
      );
    });

    test('a product without add-ons (older data) loads with none', () {
      final p = Product.fromMap('x', {'name': 'Old', 'companyId': 'c'});
      expect(p.addOns, isEmpty);
      expect(AddOnRules.hasAvailable(p), isFalse);
    });

    test('add-ons round-trip through the product map', () {
      final p = Product.fromMap('p_bed', bed(selection: 'radio').toMap());
      expect(p.addOns.map((a) => a.id), [
        'ao_delivery',
        'ao_assembly',
        'ao_old',
      ]);
      expect(p.addOns[1].description, 'Fitted by our team');
      expect(p.addOns[1].price, 800);
      expect(p.addOns[1].mrp, 1000);
      expect(p.addOns[2].isActive, isFalse);
      expect(p.addOnSelection, 'radio');
    });

    test('an add-on map without isActive is enabled', () {
      expect(
        ProductAddOn.fromMap({'id': 'a', 'title': 'T', 'amount': 5}).isActive,
        isTrue,
      );
    });

    test('price follows the discount; a bad discount is ignored', () {
      expect(assembly.price, 800);
      expect(assembly.isDiscounted, isTrue);
      expect(
        const ProductAddOn(
          id: 'a',
          title: 'A',
          amount: 100,
          discountAmt: 150,
        ).price,
        100,
      );
    });
  });

  group('selection rules', () {
    test('only enabled add-ons are available, in the admin order', () {
      expect(AddOnRules.available(bed()).map((a) => a.id), [
        'ao_delivery',
        'ao_assembly',
      ]);
      expect(AddOnRules.hasAvailable(bed(addOns: const [retired])), isFalse);
    });

    test('checkbox allows several and toggles each one off', () {
      final p = bed();
      var sel = <String>[];
      sel = AddOnRules.toggle(p, sel, 'ao_delivery');
      sel = AddOnRules.toggle(p, sel, 'ao_assembly');
      expect(sel, ['ao_delivery', 'ao_assembly']);
      sel = AddOnRules.toggle(p, sel, 'ao_delivery');
      expect(sel, ['ao_assembly']);
    });

    test('radio keeps one: picking another swaps, tapping again clears', () {
      final p = bed(selection: AddOnSelectionType.radio);
      var sel = AddOnRules.toggle(p, [], 'ao_delivery');
      expect(sel, ['ao_delivery']);
      sel = AddOnRules.toggle(p, sel, 'ao_assembly');
      expect(sel, ['ao_assembly']);
      sel = AddOnRules.toggle(p, sel, 'ao_assembly');
      expect(sel, isEmpty);
    });

    test('a disabled or unknown add-on cannot be toggled on', () {
      final p = bed();
      expect(AddOnRules.toggle(p, [], 'ao_old'), isEmpty);
      expect(AddOnRules.toggle(p, [], 'nope'), isEmpty);
    });

    test('resolve rejects unknown, disabled and over-picked radio', () {
      expect(
        () => AddOnRules.resolve(bed(), ['nope']),
        throwsA(
          isA<AddOnSelectionException>().having(
            (e) => e.error,
            'error',
            AddOnSelectionError.unknownAddOn,
          ),
        ),
      );
      expect(
        () => AddOnRules.resolve(bed(), ['ao_old']),
        throwsA(
          isA<AddOnSelectionException>().having(
            (e) => e.error,
            'error',
            AddOnSelectionError.unavailableAddOn,
          ),
        ),
      );
      expect(
        () => AddOnRules.resolve(bed(selection: AddOnSelectionType.radio), [
          'ao_delivery',
          'ao_assembly',
        ]),
        throwsA(
          isA<AddOnSelectionException>().having(
            (e) => e.error,
            'error',
            AddOnSelectionError.tooManyForRadio,
          ),
        ),
      );
    });

    test('resolve counts a duplicated id once and keeps product order', () {
      final r = AddOnRules.resolve(bed(), [
        'ao_assembly',
        'ao_delivery',
        'ao_assembly',
      ]);
      expect(r.map((a) => a.addOnId), ['ao_delivery', 'ao_assembly']);
    });

    test('no selection resolves to nothing', () {
      expect(AddOnRules.resolve(bed(), const []), isEmpty);
    });
  });

  group('admin validation', () {
    AddOnFormIssue? check({
      String title = 'T',
      String price = '10',
      String discount = '',
      String image = '',
    }) => AddOnRules.validateFields(
      title: title,
      price: price,
      discount: discount,
      imageUrl: image,
    );

    test('accepts a minimal and a full add-on', () {
      expect(check(), isNull);
      expect(check(price: '0'), isNull); // free add-on
      expect(check(discount: '5', image: 'https://x.test/a.png'), isNull);
    });

    test('title is required', () {
      expect(check(title: '  '), AddOnFormIssue.titleRequired);
    });

    test('price must be a number, not negative', () {
      expect(check(price: ''), AddOnFormIssue.invalidPrice);
      expect(check(price: 'abc'), AddOnFormIssue.invalidPrice);
      expect(check(price: '-1'), AddOnFormIssue.invalidPrice);
    });

    test('discount must be below the price', () {
      expect(check(discount: '10'), AddOnFormIssue.invalidDiscount);
      expect(check(discount: '11'), AddOnFormIssue.invalidDiscount);
      expect(check(discount: '-2'), AddOnFormIssue.invalidDiscount);
      expect(check(discount: 'x'), AddOnFormIssue.invalidDiscount);
    });

    test('image must be an http(s) link when given', () {
      expect(check(image: 'ftp://x'), AddOnFormIssue.invalidImage);
      expect(check(image: 'photo.png'), AddOnFormIssue.invalidImage);
    });

    test('duplicate titles are caught across the list', () {
      expect(
        AddOnRules.validateList(const [
          ProductAddOn(id: 'a', title: 'Assembly', amount: 1),
          ProductAddOn(id: 'b', title: ' assembly ', amount: 2),
        ]),
        AddOnFormIssue.duplicateTitle,
      );
      expect(AddOnRules.validateList(bed().addOns), isNull);
      expect(AddOnRules.validateList(const []), isNull);
    });

    test('new ids are unique', () {
      final ids = {for (var i = 0; i < 50; i++) AddOnRules.newId()};
      expect(ids.length, greaterThan(1));
    });
  });

  group('pricing', () {
    test('add-ons are an extra charge on top of the product price', () {
      final item = line(bed(), ids: ['ao_delivery', 'ao_assembly']);
      expect(item.effectivePrice, 18000);
      expect(item.addOnUnitPrice, 1300); // 500 + 800 (discounted)
      expect(item.unitPriceWithAddOns, 19300);
      expect(item.lineTotal, 19300);
      expect(item.unitMrpWithAddOns, 20000 + 500 + 1000);
    });

    test('add-ons are charged per unit', () {
      final item = line(bed(), ids: ['ao_assembly'], qty: 3);
      expect(item.lineTotal, 3 * (18000 + 800));
      expect(item.addOnLineTotal, 3 * 800);
    });

    test('no add-ons leaves the price exactly as before', () {
      final item = line(bed(), qty: 2);
      expect(item.lineTotal, 36000);
      expect(item.unitPriceWithAddOns, 18000);
      expect(item.addOnLineTotal, 0);
    });

    test('add-ons ride on the selected variant price', () {
      final p = bed().copyWith(
        variants: const [
          ProductVariant(
            sku: 'KING',
            title: 'King',
            priceOverride: 25000,
            mrpOverride: 28000,
            stockQty: 2,
          ),
        ],
      );
      final item = line(p, ids: ['ao_delivery'], variant: p.variants.first);
      expect(item.unitPriceWithAddOns, 25500);
    });

    test('sums are exact to the paisa (no float noise)', () {
      const a = ProductAddOn(id: 'a', title: 'A', amount: 0.1);
      const b = ProductAddOn(id: 'b', title: 'B', amount: 0.2);
      const p = Product(
        id: 'p',
        companyId: 'c',
        name: 'P',
        amount: 99.99,
        stockQty: 9,
        addOns: [a, b],
      );
      final item = line(p, ids: ['a', 'b'], qty: 3);
      expect(item.addOnUnitPrice, 0.3);
      expect(item.unitPriceWithAddOns, 100.29);
      expect(item.lineTotal, 300.87);
      expect(const CartCalculator().line(item).itemTotal, 300.87);
    });

    test('CartCalculator totals include add-ons and the discount shows', () {
      final items = [
        line(bed(), ids: ['ao_assembly'], qty: 2),
        line(bed(), qty: 1),
      ];
      final s = const CartCalculator().summary(items, deliveryCharge: 100);
      expect(s.subtotal, 2 * 18800 + 18000);
      expect(s.totalMrp, 2 * 21000 + 20000);
      expect(s.grandTotal, s.subtotal + 100);
      expect(s.totalItems, 3);
    });
  });

  group('cart', () {
    test('same product with different add-ons are different lines', () {
      final a = line(bed(), ids: ['ao_delivery']);
      final b = line(bed(), ids: ['ao_assembly']);
      final c = line(bed());
      expect({a.cartKey, b.cartKey, c.cartKey}.length, 3);
    });

    test('same add-ons in any order are one line', () {
      expect(
        line(bed(), ids: ['ao_delivery', 'ao_assembly']).cartKey,
        line(bed(), ids: ['ao_assembly', 'ao_delivery']).cartKey,
      );
    });

    test('a line without add-ons keeps the old key', () {
      expect(line(bed()).cartKey, 'p_bed');
    });

    test('cubit merges identical configurations and splits the rest', () {
      SharedPreferences.setMockInitialValues({});
      final cart = CartCubit(CartStorage());
      addTearDown(cart.close);
      final p = bed();
      final delivery1 = AddOnRules.resolve(p, ['ao_delivery']);
      cart.add(p, qty: 1, addOns: delivery1);
      cart.add(p, qty: 2, addOns: delivery1);
      cart.add(p, qty: 1, addOns: AddOnRules.resolve(p, ['ao_assembly']));
      cart.add(p, qty: 1);
      expect(cart.state.items.length, 3);
      final merged = cart.state.items.firstWhere(
        (e) => e.addOns.length == 1 && e.addOns.first.addOnId == 'ao_delivery',
      );
      expect(merged.qty, 3);
      expect(cart.state.totalAmount, 3 * 18500 + 18800 + 18000);
    });

    test('cart rows survive a restart with their add-ons', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = CartStorage();
      final first = CartCubit(storage);
      final p = bed();
      first.add(p, qty: 2, addOns: AddOnRules.resolve(p, ['ao_assembly']));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await first.close();

      final second = CartCubit(storage);
      addTearDown(second.close);
      await second.loadFromStorage();
      final restored = second.state.items.single;
      expect(restored.addOns.single.addOnId, 'ao_assembly');
      expect(restored.addOns.single.title, 'Assembly');
      expect(restored.addOns.single.price, 800);
      expect(restored.qty, 2);
      expect(restored.lineTotal, 2 * 18800);
      expect(restored.cartKey, 'p_bed+ao_assembly');
    });

    test('an old saved cart row without add-ons still loads', () {
      final item = CartItem.fromMap({
        'productId': 'p_bed',
        'companyId': 'c_wood',
        'quantity': 2,
        'product': bed(addOns: const []).toMap(),
      });
      expect(item.addOns, isEmpty);
      expect(item.cartKey, 'p_bed');
    });

    test('replaceItem moves a line to its new key and merges twins', () {
      SharedPreferences.setMockInitialValues({});
      final cart = CartCubit(CartStorage());
      addTearDown(cart.close);
      final p = bed();
      cart.add(p, qty: 1, addOns: AddOnRules.resolve(p, ['ao_assembly']));
      cart.add(p, qty: 2);
      final withAddOn = cart.state.items.firstWhere((e) => e.addOns.isNotEmpty);
      // The add-on was disabled: the line loses it and becomes the plain one.
      cart.replaceItem(withAddOn.cartKey, withAddOn.copyWith(addOns: const []));
      expect(cart.state.items.length, 1);
      expect(cart.state.items.single.qty, 3);
      expect(cart.state.items.single.addOns, isEmpty);
    });
  });

  group('re-validation against the live catalogue', () {
    final chosen = AddOnRules.resolve(bed(), ['ao_delivery', 'ao_assembly']);

    test('unchanged add-ons report no change', () {
      final r = AddOnRules.refresh(bed(), chosen);
      expect(r.changed, isFalse);
      expect(r.addOns.length, 2);
    });

    test('a disabled add-on is dropped', () {
      final latest = bed(
        addOns: [delivery.copyWith(isActive: false), assembly],
      );
      final r = AddOnRules.refresh(latest, chosen);
      expect(r.addOns.map((a) => a.addOnId), ['ao_assembly']);
      expect(r.removedTitles, ['Delivery to floor']);
    });

    test('a deleted add-on is dropped', () {
      final r = AddOnRules.refresh(bed(addOns: const [delivery]), chosen);
      expect(r.addOns.map((a) => a.addOnId), ['ao_delivery']);
      expect(r.removedTitles, ['Assembly']);
    });

    test('a price change is picked up from the catalogue', () {
      final latest = bed(addOns: [delivery.copyWith(amount: 650), assembly]);
      final r = AddOnRules.refresh(latest, chosen);
      expect(r.priceChanged, isTrue);
      expect(r.addOns.first.price, 650);
    });

    test('a client-tampered price is replaced by the catalogue price', () {
      final tampered = [
        const AddOnSnapshot(
          addOnId: 'ao_delivery',
          title: 'Delivery',
          price: 1,
        ),
      ];
      final r = AddOnRules.refresh(bed(), tampered);
      expect(r.addOns.single.price, 500);
      expect(r.priceChanged, isTrue);
    });

    test('a product switched to radio keeps only the first add-on', () {
      final r = AddOnRules.refresh(
        bed(selection: AddOnSelectionType.radio),
        chosen,
      );
      expect(r.addOns.length, 1);
      expect(r.removedTitles.length, 1);
    });
  });

  group('order payload', () {
    OrderBill bill(List<CartItem> items) => const OrderPricer().price(
      companyId: 'c_wood',
      companyName: 'Woodnest',
      items: items,
      deliveryCharge: 100,
    );

    test('priced lines carry add-ons and the totals include them', () {
      final b = bill([
        line(bed(), ids: ['ao_delivery', 'ao_assembly'], qty: 2),
      ]);
      final l = b.lines.single;
      expect(l.unitPrice, 19300);
      expect(l.lineTotal, 38600);
      expect(l.addOns.map((a) => a.title), ['Delivery to floor', 'Assembly']);
      expect(b.subtotal, 38600);
      expect(b.total, 38700);
      expect(b.toMap()['lines'][0]['addOns'].length, 2);
    });

    test('a plain line has an empty add-on list', () {
      final b = bill([line(bed())]);
      expect(b.lines.single.addOns, isEmpty);
      expect(b.total, 18100);
    });

    test('OrderItem keeps add-ons through its map and reports base price', () {
      final l = bill([
        line(bed(), ids: ['ao_assembly']),
      ]).lines.single;
      final item = OrderItem(
        productId: l.productId,
        qty: l.qty,
        unitPrice: l.unitPrice,
        mrp: l.mrp,
        name: l.name,
        addOns: l.addOns,
      );
      final back = OrderItem.fromMap(item.toMap());
      expect(back.addOns.single.addOnId, 'ao_assembly');
      expect(back.addOns.single.price, 800);
      expect(back.unitPrice, 18800);
      expect(back.baseUnitPrice, 18000);
      expect(back.itemTotal, 18800);
      expect(item.toMap()['addOnsUnitTotal'], 800);
    });

    test('an old order item without add-ons still reads', () {
      final item = OrderItem.fromMap({
        'productId': 'p',
        'qty': 2,
        'unitPrice': 10,
      });
      expect(item.addOns, isEmpty);
      expect(item.itemTotal, 20);
    });
  });
}
