import '../models/product.dart';
import '../models/product_addon.dart';

/// Why a set of selected add-ons is not acceptable.
enum AddOnSelectionError {
  /// An id that the product does not have.
  unknownAddOn,

  /// The add-on exists but is disabled / unavailable.
  unavailableAddOn,

  /// Several add-ons were picked where only one is allowed (radio).
  tooManyForRadio,
}

class AddOnSelectionException implements Exception {
  final AddOnSelectionError error;
  final String addOnId;
  const AddOnSelectionException(this.error, [this.addOnId = '']);

  @override
  String toString() => 'AddOnSelectionException($error $addOnId)';
}

/// Why an add-on cannot be saved by the admin.
enum AddOnFormIssue {
  titleRequired,
  invalidPrice,
  invalidDiscount,
  invalidImage,
  duplicateTitle,
}

/// What a re-check of an old selection against the live catalogue found.
class AddOnRefresh {
  /// The selection to keep, priced from the live catalogue.
  final List<AddOnSnapshot> addOns;

  /// Titles that are gone, disabled, or no longer allowed together.
  final List<String> removedTitles;

  /// True when at least one kept add-on has a different price now.
  final bool priceChanged;

  const AddOnRefresh({
    required this.addOns,
    this.removedTitles = const [],
    this.priceChanged = false,
  });

  bool get changed => removedTitles.isNotEmpty || priceChanged;
}

/// The business rules for product add-ons: what can be saved, what can be
/// picked, and what the live catalogue says about a selection.
///
/// The one place both the admin form, the shop sheet, the cart and checkout
/// ask — so they cannot disagree.
class AddOnRules {
  const AddOnRules._();

  /// Add-ons a shopper can pick, in the admin's order.
  static List<ProductAddOn> available(Product product) =>
      product.addOns.where((a) => a.isAvailable).toList();

  static bool hasAvailable(Product product) =>
      product.addOns.any((a) => a.isAvailable);

  static bool isRadio(Product product) =>
      product.addOnSelection == AddOnSelectionType.radio;

  /// The selection after toggling [addOnId], keeping the rules:
  /// checkbox adds/removes it; radio picks it (tapping the chosen one again
  /// clears it, since add-ons stay optional). Unavailable ids are ignored.
  static List<String> toggle(
    Product product,
    List<String> selected,
    String addOnId,
  ) {
    final target = product.addOns.where((a) => a.id == addOnId);
    if (target.isEmpty || !target.first.isAvailable) {
      return List<String>.of(selected);
    }
    final isSelected = selected.contains(addOnId);
    if (isRadio(product)) {
      return isSelected ? <String>[] : <String>[addOnId];
    }
    return isSelected
        ? selected.where((id) => id != addOnId).toList()
        : [...selected, addOnId];
  }

  /// Turns picked ids into snapshots, in the product's order.
  ///
  /// Duplicated ids count once. Throws [AddOnSelectionException] for unknown
  /// or disabled add-ons, and for more than one pick on a radio product.
  static List<AddOnSnapshot> resolve(Product product, Iterable<String> ids) {
    final wanted = ids.toSet();
    if (wanted.isEmpty) return const [];
    final byId = {for (final a in product.addOns) a.id: a};
    for (final id in wanted) {
      final a = byId[id];
      if (a == null) {
        throw AddOnSelectionException(AddOnSelectionError.unknownAddOn, id);
      }
      if (!a.isAvailable) {
        throw AddOnSelectionException(AddOnSelectionError.unavailableAddOn, id);
      }
    }
    if (isRadio(product) && wanted.length > 1) {
      throw const AddOnSelectionException(AddOnSelectionError.tooManyForRadio);
    }
    return [
      for (final a in product.addOns)
        if (wanted.contains(a.id)) AddOnSnapshot.from(a),
    ];
  }

  /// Re-checks [current] against the live [latest] product (checkout does this
  /// for every line): disabled or deleted add-ons are dropped, prices follow
  /// the catalogue, and a radio product keeps at most one.
  static AddOnRefresh refresh(Product latest, List<AddOnSnapshot> current) {
    if (current.isEmpty) return const AddOnRefresh(addOns: []);
    final byId = {for (final a in latest.addOns) a.id: a};
    final kept = <AddOnSnapshot>[];
    final removed = <String>[];
    var priceChanged = false;
    final seen = <String>{};
    for (final old in current) {
      if (!seen.add(old.addOnId)) continue;
      final live = byId[old.addOnId];
      if (live == null || !live.isAvailable) {
        removed.add(old.title);
        continue;
      }
      final fresh = AddOnSnapshot.from(live);
      if (toPaise(fresh.price) != toPaise(old.price) ||
          toPaise(fresh.mrp) != toPaise(old.mrp)) {
        priceChanged = true;
      }
      kept.add(fresh);
    }
    if (isRadio(latest) && kept.length > 1) {
      removed.addAll(kept.skip(1).map((a) => a.title));
      kept.removeRange(1, kept.length);
    }
    return AddOnRefresh(
      addOns: kept,
      removedTitles: removed,
      priceChanged: priceChanged,
    );
  }

  /// First problem with an add-on being saved, or null when it is fine.
  ///
  /// [price] and [discount] are the raw field texts (an empty discount means
  /// none), so the form and the save step share one rule set.
  static AddOnFormIssue? validateFields({
    required String title,
    required String price,
    String discount = '',
    String imageUrl = '',
  }) {
    if (title.trim().isEmpty) return AddOnFormIssue.titleRequired;
    final amount = double.tryParse(price.trim());
    if (amount == null || amount < 0 || amount.isNaN || amount.isInfinite) {
      return AddOnFormIssue.invalidPrice;
    }
    final d = discount.trim();
    if (d.isNotEmpty) {
      final disc = double.tryParse(d);
      if (disc == null || disc < 0 || disc >= amount || disc.isNaN) {
        return AddOnFormIssue.invalidDiscount;
      }
    }
    final img = imageUrl.trim();
    if (img.isNotEmpty &&
        !(img.startsWith('http://') || img.startsWith('https://'))) {
      return AddOnFormIssue.invalidImage;
    }
    return null;
  }

  /// First problem across a product's add-ons (used before saving it).
  static AddOnFormIssue? validateList(List<ProductAddOn> addOns) {
    final titles = <String>{};
    for (final a in addOns) {
      final issue = validateFields(
        title: a.title,
        price: a.amount.toString(),
        discount: a.discountAmt > 0 ? a.discountAmt.toString() : '',
        imageUrl: a.imageUrl,
      );
      if (issue != null) return issue;
      if (!titles.add(a.title.trim().toLowerCase())) {
        return AddOnFormIssue.duplicateTitle;
      }
    }
    return null;
  }

  /// Unique id for a new add-on.
  static String newId() => 'ao_${DateTime.now().microsecondsSinceEpoch}';
}
