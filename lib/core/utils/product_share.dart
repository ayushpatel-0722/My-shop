import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/product.dart';
import '../services/qr_deep_link_service.dart';

/// Shares a product's direct link through the device's share sheet.
///
/// The link is the one the Admin product QR code and "Product Link" use
/// ([QrDeepLinkService.buildProductUrl]: `<domain>/shop/<shopId>/product/<id>`),
/// so a link shared from here and a scanned admin QR open the same page.
class ProductShare {
  const ProductShare._();

  /// The canonical link for [product] (shop id = the product's owner, exactly
  /// as the admin screens use it).
  static String linkFor(Product product) =>
      QrDeepLinkService.buildProductUrl(product.companyId, product.id);

  /// What goes into the message next to the link.
  static String messageFor(Product product, {String? shopName}) {
    final shop = (shopName ?? '').trim();
    final title = shop.isEmpty ? product.name : '${product.name} · $shop';
    return '$title\n${linkFor(product)}';
  }

  /// Opens the share sheet. Replaceable in tests.
  @visibleForTesting
  static Future<void> Function(ShareParams params) sharer = (params) async {
    await SharePlus.instance.share(params);
  };

  /// Shares [product]; if the platform has no share sheet (some browsers),
  /// copies the link instead.
  static Future<void> share(
    BuildContext context,
    Product product, {
    String? shopName,
  }) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null; // iPad needs an anchor for the popover
    try {
      await sharer(
        ShareParams(
          text: messageFor(product, shopName: shopName),
          subject: product.name,
          sharePositionOrigin: origin,
        ),
      );
    } catch (e) {
      debugPrint('Share failed, copying link instead: $e');
      if (context.mounted) {
        await QrDeepLinkService.copyToClipboard(context, linkFor(product));
      }
    }
  }
}
