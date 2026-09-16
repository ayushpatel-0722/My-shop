import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../app/routes/app_router.dart';
import '../../../core/models/banner.dart';
import '../../../core/models/category.dart';
import '../../../core/models/company.dart';
import '../../../core/models/product.dart';
import '../../../core/models/voucher.dart';
import '../../../core/services/service_locator.dart';
import '../widgets/product_card.dart';
import '../widgets/section_header.dart';

/// Intelligent home feed (Section 13.2): ads carousel, brand rail, voucher
/// marquee, recommendations and category grid.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _carouselCtrl = PageController();
  int _carouselIndex = 0;

  @override
  void dispose() {
    _carouselCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final companies = repo.companies();
    final categories = repo.categories();
    final ads = repo.adBanners();
    final recs = repo.recommendations();
    final vouchers = repo.vouchers('');

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => context.go(AppRoutes.search)),
          IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => context.go(AppRoutes.notifications)),
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            onPressed: () => context.go(AppRoutes.cart),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _adsCarousel(ads),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SectionHeader(title: l10n.brandStores),
          ),
          SizedBox(height: 110, child: _brandRail(companies)),
          const SizedBox(height: 8),
          _voucherMarquee(vouchers, l10n),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SectionHeader(title: l10n.recommendedForYou),
          ),
          _recommendationsGrid(recs),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SectionHeader(title: l10n.categories),
          ),
          _categoryGrid(categories),
        ],
      ),
    );
  }

  Widget _adsCarousel(Stream<List<AdBanner>> ads) {
    return StreamBuilder<List<AdBanner>>(
      stream: ads,
      builder: (context, snap) {
        final list = snap.data ?? const <AdBanner>[];
        if (list.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 160,
          child: Stack(
            children: [
              PageView.builder(
                controller: _carouselCtrl,
                itemCount: list.length,
                onPageChanged: (i) => setState(() => _carouselIndex = i),
                itemBuilder: (context, i) => _adCard(context, list[i]),
              ),
              Positioned(
                bottom: 8,
                right: 0,
                left: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    list.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _carouselIndex ? 20 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _carouselIndex
                            ? Theme.of(context).colorScheme.primary
                            : Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _adCard(BuildContext context, AdBanner ad) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.campaign, size: 36, color: Colors.white),
            const SizedBox(height: 8),
            Text('Platform Ad · ${ad.actionTarget}',
                style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _brandRail(Stream<List<Company>> companies) {
    return StreamBuilder<List<Company>>(
      stream: companies,
      builder: (context, snap) {
        final list = snap.data ?? const <Company>[];
        if (list.isEmpty) return const SizedBox.shrink();
        return ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, i) => _brandCard(context, list[i]),
        );
      },
    );
  }

  Widget _brandCard(BuildContext context, Company company) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => context.go(AppRoutes.companyPath(company.slug)),
      child: Column(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: scheme.primaryContainer,
            child: Text(company.name.substring(0, 1).toUpperCase(),
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: scheme.primary)),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 76,
            child: Text(company.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _voucherMarquee(
      Stream<List<Voucher>> vouchers, AppLocalizations l10n) {
    return StreamBuilder<List<Voucher>>(
      stream: vouchers,
      builder: (context, snap) {
        final list = snap.data ?? const <Voucher>[];
        return SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              const Icon(Icons.local_offer, size: 20),
              const SizedBox(width: 6),
              Text(l10n.trendingNow,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              for (final v in list.take(5)) ...[
                const SizedBox(width: 12),
                Text('${v.code} · ${v.discountValue}${v.discountType == 'percentage' ? '%' : ''}',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _recommendationsGrid(Future<List<Product>> recs) {
    return FutureBuilder<List<Product>>(
      future: recs,
      builder: (context, snap) {
        final list = snap.data ?? const <Product>[];
        if (list.isEmpty) return const SizedBox.shrink();
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
              onTap: () => context.go(AppRoutes.productPath(list[i].id)),
            ),
          ),
        );
      },
    );
  }

  Widget _categoryGrid(Stream<List<Category>> categories) {
    return StreamBuilder<List<Category>>(
      stream: categories,
      builder: (context, snap) {
        final list = snap.data ?? const <Category>[];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: list.length,
            itemBuilder: (context, i) => InkWell(
              onTap: () => context.go(
                  '${AppRoutes.categoryPath(list[i].id)}?name=${list[i].name}'),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(list[i].iconUrl, style: const TextStyle(fontSize: 28)),
                    const SizedBox(height: 6),
                    Text(list[i].name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
