import 'dart:convert';
import 'package:flutter/material.dart';

import '../models/product.dart';

/// A robust image widget for products and categories that gracefully handles:
/// - Primary and secondary online network images (http://, https://, //)
/// - Multi-image cascade fallback: if primary fails, seamlessly tries subsequent images
/// - Base64 Data URIs (data:image/...;base64,...)
/// - Loading indicator with configurable size
/// - Custom or standard fallback on error/empty
/// - Optional border radius clipping
class AppProductImage extends StatelessWidget {
  final String? url;
  final List<String>? urls;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Widget? fallback;
  final Widget? loadingWidget;

  const AppProductImage({
    super.key,
    required this.url,
    this.urls,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.fallback,
    this.loadingWidget,
  });

  AppProductImage.product({
    super.key,
    required Product product,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.fallback,
    this.loadingWidget,
  }) : url = product.imageUrl,
       urls = product.images;

  @override
  Widget build(BuildContext context) {
    final primary = (url != null && url!.trim().isNotEmpty)
        ? url!.trim()
        : (urls != null && urls!.isNotEmpty ? urls!.first.trim() : '');

    final defaultFallback =
        fallback ??
        Container(
          width: width,
          height: height,
          color: const Color(0xFFF1F5F9),
          child: const Center(
            child: Icon(
              Icons.inventory_2_outlined,
              size: 24,
              color: Color(0xFF94A3B8),
            ),
          ),
        );

    if (primary.isEmpty) {
      return _wrapRadius(defaultFallback);
    }

    Widget content;

    // 1. Base64 Data URI
    if (primary.startsWith('data:image')) {
      try {
        final comma = primary.indexOf(',');
        final base64Str = comma != -1 ? primary.substring(comma + 1) : primary;
        final bytes = base64Decode(base64Str);
        content = Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, _, _) => defaultFallback,
        );
      } catch (_) {
        content = defaultFallback;
      }
    }
    // 2. Flutter Asset (if any legacy assets exist)
    else if (primary.startsWith('assets/')) {
      content = Image.asset(
        primary,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, _) => defaultFallback,
      );
    }
    // 3. Online Network Image with multi-image cascade fallback
    else {
      final candidates = <String>[];
      if (primary.isNotEmpty) candidates.add(primary);
      if (urls != null) {
        for (final u in urls!) {
          final trimmed = u.trim();
          if (trimmed.isNotEmpty && !candidates.contains(trimmed)) {
            candidates.add(trimmed);
          }
        }
      }

      Widget current = defaultFallback;
      for (int i = candidates.length - 1; i >= 0; i--) {
        current = _buildNetworkImage(candidates[i], current);
      }
      content = current;
    }

    return _wrapRadius(content);
  }

  Widget _buildNetworkImage(String targetUrl, Widget fallbackWidget) {
    final effectiveUrl = targetUrl.startsWith('//')
        ? 'https:$targetUrl'
        : (targetUrl.startsWith('http://') || targetUrl.startsWith('https://'))
        ? targetUrl
        : 'https://$targetUrl';

    return Image.network(
      effectiveUrl,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        if (loadingWidget != null) return loadingWidget!;
        return Container(
          width: width,
          height: height,
          color: const Color(0xFFF8F9FA),
          child: Center(
            child: SizedBox(
              width: (width != null && width! < 30) ? 14 : 20,
              height: (height != null && height! < 30) ? 14 : 20,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
      errorBuilder: (_, _, _) => fallbackWidget,
    );
  }

  Widget _wrapRadius(Widget child) {
    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: child);
    }
    return child;
  }
}
