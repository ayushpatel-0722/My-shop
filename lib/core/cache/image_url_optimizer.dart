/// Picks a smaller version of an image when the host offers one, so a 64 px
/// thumbnail does not download a 1920 px photo.
///
/// Only URLs of hosts known to resize on request are touched, and an image is
/// only ever made smaller than the URL already asks for. Anything else is
/// returned unchanged.
class ImageUrlOptimizer {
  const ImageUrlOptimizer._();

  /// Widths Wikimedia serves for thumbnails (other sizes are refused).
  static const List<int> wikimediaWidths = [250, 330, 500, 960, 1280, 1920];

  /// [url] for an image shown [pixelWidth] device pixels wide (0 = unknown).
  static String forWidth(String url, int pixelWidth) {
    if (pixelWidth <= 0) return url;
    final wiki = RegExp(
      r'^(.*/thumb/.+/)(\d+)px(-[^/?]+)(\?.*)?$',
    ).firstMatch(url);
    if (wiki != null && url.contains('.wikimedia.org/')) {
      final current = int.parse(wiki.group(2)!);
      final want = wikimediaWidths.firstWhere(
        (w) => w >= pixelWidth,
        orElse: () => wikimediaWidths.last,
      );
      if (want >= current) return url; // never enlarge
      return '${wiki.group(1)}${want}px${wiki.group(3)}${wiki.group(4) ?? ''}';
    }
    final uri = Uri.tryParse(url);
    if (uri != null && uri.host == 'images.unsplash.com') {
      final current = int.tryParse(uri.queryParameters['w'] ?? '');
      final want = ((pixelWidth + 99) ~/ 100) * 100;
      if (current != null && want >= current) return url;
      return uri
          .replace(queryParameters: {...uri.queryParameters, 'w': '$want'})
          .toString();
    }
    return url;
  }
}
