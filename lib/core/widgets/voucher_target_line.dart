import 'package:flutter/material.dart';

import '../../app/l10n/app_localizations.dart';
import '../domain/voucher_target.dart';
import '../models/category.dart';
import '../models/company.dart';
import '../models/product.dart';
import '../models/voucher.dart';
import '../services/service_locator.dart';
import 'replay_stream_builder.dart';

/// How [VoucherTargetLine] lays the information out.
enum VoucherTargetLayout {
  /// One line: "Shop name · what it applies to".
  inline,

  /// Two rows, one under the other: the shop, then "Applies to: …" — each
  /// readable on its own instead of cut short on a shared line.
  column,
}

/// What a voucher is for: the shop, and what it applies to.
///
/// Reads the shop, and — only when the voucher is limited to chosen
/// categories or products — their names, through the shared (cached) queries.
/// Until a name is known it shows what it can, never a gap.
class VoucherTargetLine extends StatelessWidget {
  const VoucherTargetLine({
    super.key,
    required this.voucher,
    this.style,
    this.layout = VoucherTargetLayout.inline,
  });

  final Voucher voucher;
  final TextStyle? style;
  final VoucherTargetLayout layout;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final v = voucher;
    return ReplayStreamBuilder<List<Company>>(
      stream: repo.companies(),
      builder: (context, shops) {
        var shopName = '';
        for (final c in shops.data ?? const <Company>[]) {
          if (c.id == v.companyId) shopName = c.name;
        }

        Widget text(Map<String, String> cats, Map<String, String> prods) {
          final target = VoucherTarget.appliesTo(
            v,
            categoryNames: cats,
            productNames: prods,
            allProducts: l10n.voucherAllProducts,
            selectedCategories: l10n.voucherSelectedCategories,
            selectedProducts: l10n.voucherSelectedProducts,
            more: (n) => l10n.voucherMoreCount(n),
          );
          if (layout == VoucherTargetLayout.column) {
            final iconColor = style?.color ?? const Color(0xFF475569);
            Widget row(IconData icon, Widget text) => Row(
              children: [
                Icon(icon, size: 13, color: iconColor),
                const SizedBox(width: 5),
                Expanded(child: text),
              ],
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (shopName.trim().isNotEmpty)
                  row(
                    Icons.storefront_outlined,
                    Text(
                      shopName.trim(),
                      key: Key('voucher-shop-${v.id}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style,
                    ),
                  ),
                if (shopName.trim().isNotEmpty) const SizedBox(height: 2),
                row(
                  v.appliesTo == VoucherScope.specificProduct
                      ? Icons.shopping_bag_outlined
                      : Icons.category_outlined,
                  Text(
                    '${l10n.voucherAppliesTo}: $target',
                    key: Key('voucher-target-${v.id}'),
                    // Room for a long category or product name.
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: style,
                  ),
                ),
              ],
            );
          }
          return Text(
            VoucherTarget.label(v, shopName: shopName, target: target),
            key: Key('voucher-target-${v.id}'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          );
        }

        if (v.appliesTo == VoucherScope.specificCategory) {
          return ReplayStreamBuilder<List<Category>>(
            stream: repo.categories(companyId: v.companyId),
            builder: (context, cats) => text({
              for (final c in cats.data ?? const <Category>[]) c.id: c.name,
            }, const {}),
          );
        }
        if (v.appliesTo == VoucherScope.specificProduct) {
          return ReplayStreamBuilder<List<Product>>(
            stream: repo.products(companyId: v.companyId),
            builder: (context, prods) => text(const {}, {
              for (final p in prods.data ?? const <Product>[]) p.id: p.name,
            }),
          );
        }
        return text(const {}, const {});
      },
    );
  }
}
