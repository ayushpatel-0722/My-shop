import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:go_router/go_router.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../app/routes/app_router.dart';
import '../../../core/models/banner.dart';
import '../../../core/models/company.dart';
import '../../../core/models/product.dart';
import '../../../core/services/service_locator.dart';
import '../widgets/product_card.dart';
import '../widgets/section_header.dart';

/// Company micro-storefront (Section 13.1): header with open/closed state,
/// store-exclusive offer banners, curated recommendations and full catalog.
class CompanyStoreScreen extends StatefulWidget {
  final String slug;
  const CompanyStoreScreen({super.key, required this.slug});

  @override
  State<CompanyStoreScreen> createState() => _CompanyStoreScreenState();
}

class _CompanyStoreScreenState extends State<CompanyStoreScreen> {
  Company? _company;

  @override
  void initState() {
    super.initState();
    _resolveCompany();
  }

  Future<void> _resolveCompany() async {
    final list = await repo.companies().first;
    final c = list.where((c) => c.slug == widget.slug).firstOrNull ??
        list.where((c) => c.name == widget.slug).firstOrNull;
    if (mounted) setState(() => _company = c);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_company == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final company = _company!;
    final open = company.isOpenNow();
    return Scaffold(
      appBar: AppBar(
        title: Text(company.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.rate_review_outlined),
            onPressed: () => context.go(AppRoutes.reviews.replaceFirst(
                ':companyId', company.id)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _header(company, open, l10n),
          _offerBanners(company.id),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SectionHeader(title: l10n.recommendedForYou),
          ),
          _products(company, recommendedOnly: true),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SectionHeader(title: l10n.categories),
          ),
          _products(company),
        ],
      ),
    );
  }

  Widget _header(Company company, bool open, AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      color: scheme.primaryContainer.withOpacity(0.4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: scheme.primary,
            child: Text(company.name.substring(0, 1).toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 22)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(company.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18)),
                Text(company.details,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(company.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          Chip(
            avatar: Icon(open ? Icons.lock_open : Icons.lock,
                size: 16, color: Colors.white),
            label: Text(open ? l10n.openNow : l10n.closed),
            backgroundColor: open ? Colors.green : Colors.red,
            labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _offerBanners(String companyId) {
    return StreamBuilder<List<OfferBanner>>(
      stream: repo.offerBanners(companyId),
      builder: (context, snap) {
        final list = snap.data ?? const <OfferBanner>[];
        if (list.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => Container(
              width: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.secondary,
                      Theme.of(context).colorScheme.primary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
              ),
              child: const Center(
                child: Icon(Icons.local_offer, color: Colors.white, size: 32),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _products(Company company, {bool recommendedOnly = false}) {
    return StreamBuilder<List<Product>>(
      stream: repo.products(companyId: company.id),
      builder: (context, snap) {
        var list = snap.data ?? const <Product>[];
        if (recommendedOnly) {
          list = list.where((p) => p.isRecommended).toList();
        }
        if (list.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('No products yet')),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.72,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: list.length,
            itemBuilder: (context, i) => ProductCard(
              product: list[i],
              company: company,
              onTap: () => context.go(AppRoutes.productPath(list[i].id)),
            ),
          ),
        );
      },
    );
  }
}
