import 'package:app_links/app_links.dart';

/// Resolves `ecommerce://…` and web deep links (Section 15.2).
///
/// Routes use the helpers in `core/utils/formatters.dart`:
///   `ecommerce://product/<id>`      -> Product Detail
///   `ecommerce://category/<id>`     -> Category Explorer
///   `ecommerce://company/<slug>`    -> Company micro-storefront
///   `ecommerce://order/<id>`        -> Order tracking / packing manifest
class DeepLinkService {
  final _appLinks = AppLinks();

  /// A link that opened the app (cold start).
  Future<Uri?> getInitialLink() => _appLinks.getInitialLink();

  /// Stream of links received while the app is running.
  Stream<Uri> get stream => _appLinks.uriLinkStream;

  /// Converts an `ecommerce://…` or web URI into an internal go_router location.
  String? toRoute(Uri uri) {
    final scheme = uri.scheme.toLowerCase();

    // 1. Custom scheme: ecommerce://...
    if (scheme == 'ecommerce') {
      final host = uri.host;
      final path = uri.path.replaceFirst(RegExp(r'^/+'), '');
      final fullPath = host.isNotEmpty
          ? (path.isNotEmpty ? '/$host/$path' : '/$host')
          : '/$path';
      final query = uri.hasQuery ? '?${uri.query}' : '';
      return '${_withoutMissingIds(fullPath)}$query';
    }

    if (scheme.isNotEmpty && scheme != 'http' && scheme != 'https') {
      return null;
    }

    // 2. Hash routing on web: https://domain/#/shop/...
    if (uri.fragment.isNotEmpty) {
      var frag = uri.fragment;
      if (frag.startsWith('#')) frag = frag.substring(1);
      if (frag.startsWith('/')) {
        final q = frag.indexOf('?');
        return q < 0
            ? _withoutMissingIds(frag)
            : '${_withoutMissingIds(frag.substring(0, q))}${frag.substring(q)}';
      }
    }

    // 3. Web deep-link: https://<domain>/shop/xyz or /product/xyz
    if (uri.pathSegments.isNotEmpty) {
      final cleanPath = '/${uri.pathSegments.join('/')}';
      const recognized = [
        '/shop',
        '/product',
        '/category',
        '/company',
        '/order',
        '/cart',
        '/admin',
        '/home',
      ];
      final isRecognized = recognized.any(
        (prefix) => cleanPath == prefix || cleanPath.startsWith('$prefix/'),
      );
      if (isRecognized) {
        final query = uri.hasQuery ? '?${uri.query}' : '';
        return '${_withoutMissingIds(cleanPath)}$query';
      }
    }

    return null;
  }

  /// `/shop/<id>/product` (or `/category`) with the item id missing would be
  /// an unknown page; open the shop itself instead of an error screen.
  static String _withoutMissingIds(String path) {
    final clean = path.replaceFirst(RegExp(r'/+$'), '');
    final m = RegExp(r'^/shop/([^/]+)/(product|category)$').firstMatch(clean);
    return m != null
        ? '/shop/${m.group(1)}'
        : clean.isEmpty
        ? '/'
        : clean;
  }
}
