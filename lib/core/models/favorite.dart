/// A shopper can keep at most this many favourite products.
const int maxFavoriteProducts = 25;

/// One liked product, as stored in the user's favourites list.
///
/// Only identifiers are kept: the product itself is read from the catalogue,
/// so a price or image change never leaves a stale copy behind.
class FavoriteEntry {
  final String productId;
  final String companyId;

  /// When the product was liked. The list itself is ordered oldest first;
  /// this is informational (and survives a re-sort).
  final DateTime addedAt;

  const FavoriteEntry({
    required this.productId,
    this.companyId = '',
    required this.addedAt,
  });

  factory FavoriteEntry.fromMap(Map<String, dynamic> map) => FavoriteEntry(
    productId: map['productId']?.toString() ?? '',
    companyId: map['companyId']?.toString() ?? '',
    addedAt:
        DateTime.tryParse(map['addedAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'companyId': companyId,
    'addedAt': addedAt.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      other is FavoriteEntry && other.productId == productId;

  @override
  int get hashCode => productId.hashCode;

  @override
  String toString() => 'FavoriteEntry($productId)';
}

/// Thrown when a product is liked while the list is full and the caller did
/// not agree to replace the oldest favourite.
class FavoriteLimitReached implements Exception {
  const FavoriteLimitReached();

  @override
  String toString() =>
      'FavoriteLimitReached: at most $maxFavoriteProducts favourites';
}
