import 'dart:ui' as ui;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/environment.dart';

/// Supported deep linking targets.
enum QrEntityType { shop, category, product }

/// Service responsible for generating canonical deep-link URLs,
/// managing QR codes, and handling image export and sharing.
class QrDeepLinkService {
  const QrDeepLinkService();

  /// Canonical domain configured for the current environment.
  static String get baseUrl => EnvironmentConfig.publicDomain;

  /// Builds a canonical web deep link for a Shop.
  static String buildShopUrl(String shopId) {
    final cleanId = Uri.encodeComponent(shopId.trim());
    return '$baseUrl/shop/$cleanId';
  }

  /// Builds a canonical web deep link for a Category within a Shop.
  static String buildCategoryUrl(String shopId, String categoryId) {
    final cleanShopId = Uri.encodeComponent(shopId.trim());
    final cleanCatId = Uri.encodeComponent(categoryId.trim());
    return '$baseUrl/shop/$cleanShopId/category/$cleanCatId';
  }

  /// Builds a canonical web deep link for a Product within a Shop.
  static String buildProductUrl(String shopId, String productId) {
    final cleanShopId = Uri.encodeComponent(shopId.trim());
    final cleanProdId = Uri.encodeComponent(productId.trim());
    return '$baseUrl/shop/$cleanShopId/product/$cleanProdId';
  }

  /// Builds a custom scheme deep link for a Shop (`ecommerce://shop/:shopId`).
  static String buildShopSchemeUrl(String shopId) {
    final cleanId = Uri.encodeComponent(shopId.trim());
    return 'ecommerce://shop/$cleanId';
  }

  /// Builds a custom scheme deep link for a Category (`ecommerce://shop/:shopId/category/:categoryId`).
  static String buildCategorySchemeUrl(String shopId, String categoryId) {
    final cleanShopId = Uri.encodeComponent(shopId.trim());
    final cleanCatId = Uri.encodeComponent(categoryId.trim());
    return 'ecommerce://shop/$cleanShopId/category/$cleanCatId';
  }

  /// Builds a custom scheme deep link for a Product (`ecommerce://shop/:shopId/product/:productId`).
  static String buildProductSchemeUrl(String shopId, String productId) {
    final cleanShopId = Uri.encodeComponent(shopId.trim());
    final cleanProdId = Uri.encodeComponent(productId.trim());
    return 'ecommerce://shop/$cleanShopId/product/$cleanProdId';
  }

  /// Generates the appropriate URL for an entity type.
  static String buildUrl({
    required QrEntityType type,
    required String shopId,
    String? categoryId,
    String? productId,
  }) {
    switch (type) {
      case QrEntityType.shop:
        return buildShopUrl(shopId);
      case QrEntityType.category:
        return buildCategoryUrl(shopId, categoryId ?? '');
      case QrEntityType.product:
        return buildProductUrl(shopId, productId ?? '');
    }
  }

  /// Copies text to clipboard and provides haptic feedback.
  static Future<void> copyToClipboard(
    BuildContext context,
    String text, {
    String message = 'Link copied to clipboard!',
  }) async {
    await Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: const Color(0xFF0F766E),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Launches a URL using [url_launcher].
  static Future<bool> openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch $url: $e');
      return false;
    }
  }

  /// Captures a [GlobalKey] pointing to a [RepaintBoundary] and downloads it as a PNG.
  static Future<String?> exportQrImage({
    required GlobalKey boundaryKey,
    required String fileName,
  }) async {
    try {
      final boundary =
          boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final pngBytes = byteData.buffer.asUint8List();
      final cleanFileName = fileName.replaceAll(
        RegExp(r'[^a-zA-Z0-9_\-]'),
        '_',
      );

      final savedPath = await FileSaver.instance.saveFile(
        name: cleanFileName,
        bytes: pngBytes,
        fileExtension: 'png',
        mimeType: MimeType.png,
      );

      return savedPath;
    } catch (e) {
      debugPrint('Error exporting QR image: $e');
      return null;
    }
  }
}
