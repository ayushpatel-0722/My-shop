/// Recommendation model (Firestore: /recommendations).
class Recommendation {
  final String id;
  final String companyId; // empty = platform-wide
  final String sourceId; // userId or categoryId that triggered it
  final String? pinnedProductId; // single product the Admin linked
  final List<String> linkedProds; // fallback list
  final String strategy; // top_sellers | trending | curated | cross_sell
  final int priority;

  const Recommendation({
    required this.id,
    this.companyId = '',
    this.sourceId = '',
    this.pinnedProductId,
    this.linkedProds = const [],
    this.strategy = 'top_sellers',
    this.priority = 0,
  });

  factory Recommendation.fromMap(String id, Map<String, dynamic> map) =>
      Recommendation(
        id: id,
        companyId: map['companyId'] ?? '',
        sourceId: map['sourceId'] ?? '',
        pinnedProductId: map['pinnedProductId'],
        linkedProds: List<String>.from(map['linkedProds'] ?? const []),
        strategy: map['strategy'] ?? 'top_sellers',
        priority: map['priority'] ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'companyId': companyId,
        'sourceId': sourceId,
        'pinnedProductId': pinnedProductId,
        'linkedProds': linkedProds,
        'strategy': strategy,
        'priority': priority,
      };
}
