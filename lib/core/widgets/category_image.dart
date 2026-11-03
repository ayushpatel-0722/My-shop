import 'package:flutter/material.dart';

import '../cache/app_images.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../services/service_locator.dart';
import 'category_cover_builder.dart';

/// A category's picture, filling its parent.
///
/// Order of preference: the category's own image URL / bundled asset, then the
/// photo of the first product in the category that has one, then
/// [fallback] (an emoji or a generic icon). A broken image URL falls through
/// to the next choice instead of leaving a blank box, so every shop's
/// categories look the same on the home screen, the category list and the
/// admin pickers.
class CategoryImage extends StatelessWidget {
  final Category category;
  final Widget Function(Category category) fallback;
  final BoxFit fit;

  /// Set on the copy that was already re-read from the shop, so a category
  /// that really has no picture is not looked up again and again.
  final bool _resolved;

  const CategoryImage({
    super.key,
    required this.category,
    required this.fallback,
    this.fit = BoxFit.cover,
  }) : _resolved = false;

  const CategoryImage._resolved({
    required this.category,
    required this.fallback,
    required this.fit,
  }) : _resolved = true;

  /// A bare reference (home Explore / Trending entries only carry the id,
  /// name and shop): nothing to draw yet, so read the real category.
  bool get _isBareReference =>
      !_resolved &&
      category.companyId.isNotEmpty &&
      category.iconUrl.trim().isEmpty &&
      category.productList.isEmpty;

  @override
  Widget build(BuildContext context) {
    if (_isBareReference) {
      return _BareCategoryImage(
        category: category,
        fallback: fallback,
        fit: fit,
      );
    }
    final icon = category.iconUrl.trim();
    if (category.hasImageIcon) {
      return AppNetworkImage(
        icon,
        width: double.infinity,
        height: double.infinity,
        fit: fit,
        decodeWidth: 240,
        errorBuilder: (_, _, _) => _productCover(),
      );
    }
    if (icon.startsWith('assets/')) {
      return Image.asset(
        icon,
        width: double.infinity,
        height: double.infinity,
        fit: fit,
        errorBuilder: (_, _, _) => _productCover(),
      );
    }
    return _productCover();
  }

  Widget _productCover() {
    if (category.productList.isEmpty || category.companyId.isEmpty) {
      return fallback(category);
    }
    return StreamBuilder<List<Product>>(
      stream: repo.products(companyId: category.companyId),
      builder: (context, snap) {
        final byId = <String, String>{
          for (final p in snap.data ?? const <Product>[])
            if (p.images.isNotEmpty) p.id: p.images.first,
        };
        final urls = CategoryCoverBuilder.coversFor(category, byId);
        if (urls.isEmpty) return fallback(category);
        // The first photo, and if it can not be loaded the next one, and so
        // on, ending at the glyph — never a half-empty tile.
        Widget chain = fallback(category);
        for (final url in urls.reversed) {
          final next = chain;
          chain = AppNetworkImage(
            url,
            width: double.infinity,
            height: double.infinity,
            fit: fit,
            decodeWidth: 240,
            errorBuilder: (_, _, _) => next,
          );
        }
        return chain;
      },
    );
  }
}

/// Reads the real category once, then draws it.
class _BareCategoryImage extends StatefulWidget {
  final Category category;
  final Widget Function(Category category) fallback;
  final BoxFit fit;

  const _BareCategoryImage({
    required this.category,
    required this.fallback,
    required this.fit,
  });

  @override
  State<_BareCategoryImage> createState() => _BareCategoryImageState();
}

class _BareCategoryImageState extends State<_BareCategoryImage> {
  late Future<Category?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(_BareCategoryImage old) {
    super.didUpdateWidget(old);
    if (old.category.id != widget.category.id ||
        old.category.companyId != widget.category.companyId) {
      _future = _load();
    }
  }

  Future<Category?> _load() async {
    try {
      return await repo.category(
        widget.category.id,
        companyId: widget.category.companyId,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Category?>(
      future: _future,
      builder: (context, snap) {
        final real = snap.data;
        if (real == null) return widget.fallback(widget.category);
        return CategoryImage._resolved(
          category: real,
          fallback: widget.fallback,
          fit: widget.fit,
        );
      },
    );
  }
}
