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

  /// Converts an `ecommerce://…` URI into an internal go_router location.
  String? toRoute(Uri uri) {
    final scheme = uri.scheme;
    final path = uri.path; // e.g. /product/xyz
    if (scheme == 'ecommerce') {
      return '/${path.replaceFirst(RegExp(r'^/'), '')}';
    }
    // Web deep-link host form: https://<domain>/product/xyz
    if (uri.host.isNotEmpty && uri.pathSegments.length >= 2) {
      return '/${uri.pathSegments.join('/')}';
    }
    return null;
  }
}
