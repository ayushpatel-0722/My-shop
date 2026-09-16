/// Banner models: platform-wide ads vs company offers.
enum BannerActionType { product, category, companyPage, externalUrl }

class AdBanner {
  final String id;
  final String image;
  final BannerActionType actionType;
  final String actionTarget;
  final DateTime? startDate;
  final DateTime? endDate;
  final int priority;

  const AdBanner({
    required this.id,
    required this.image,
    this.actionType = BannerActionType.product,
    this.actionTarget = '',
    this.startDate,
    this.endDate,
    this.priority = 0,
  });

  factory AdBanner.fromMap(String id, Map<String, dynamic> map) => AdBanner(
        id: id,
        image: map['image'] ?? '',
        actionType: _actionFrom(map['actionType']),
        actionTarget: map['actionTarget'] ?? '',
        startDate: map['startDate'] != null
            ? DateTime.tryParse(map['startDate'].toString())
            : null,
        endDate: map['endDate'] != null
            ? DateTime.tryParse(map['endDate'].toString())
            : null,
        priority: map['priority'] ?? 0,
      );

  static BannerActionType _actionFrom(String s) => switch (s) {
        'category' => BannerActionType.category,
        'company_page' => BannerActionType.companyPage,
        'external_url' => BannerActionType.externalUrl,
        _ => BannerActionType.product,
      };
}

class OfferBanner {
  final String id;
  final String companyId;
  final String image;
  final String? targetCatId;
  final String? targetProdId;
  final BannerActionType actionType;
  final DateTime? startDate;
  final DateTime? endDate;
  final int priority;

  const OfferBanner({
    required this.id,
    required this.companyId,
    required this.image,
    this.targetCatId,
    this.targetProdId,
    this.actionType = BannerActionType.product,
    this.startDate,
    this.endDate,
    this.priority = 0,
  });

  factory OfferBanner.fromMap(String id, Map<String, dynamic> map) => OfferBanner(
        id: id,
        companyId: map['companyId'] ?? '',
        image: map['image'] ?? '',
        targetCatId: map['targetCatId'],
        targetProdId: map['targetProdId'],
        actionType: map['actionType'] == 'category'
            ? BannerActionType.category
            : map['actionType'] == 'external_url'
                ? BannerActionType.externalUrl
                : BannerActionType.product,
        startDate: map['startDate'] != null
            ? DateTime.tryParse(map['startDate'].toString())
            : null,
        endDate: map['endDate'] != null
            ? DateTime.tryParse(map['endDate'].toString())
            : null,
        priority: map['priority'] ?? 0,
      );
}
