import 'dart:io' show Directory, Platform;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'cache_policy.dart';
import 'disk_image_cache.dart';
import 'image_url_optimizer.dart';

/// How network images are loaded.
///
///  * Android / iOS: through a bounded disk cache ([DiskImageCache]), so a
///    photo is downloaded once and survives app restarts.
///  * Web: the browser's own HTTP cache (it already stores images and manages
///    their size), so nothing is duplicated in app storage.
///  * Everywhere: smaller image versions where the host offers them, and
///    decoding no wider than the screen needs.
class AppImages {
  AppImages._();

  static CachePolicy policy = CachePolicy.standard;
  static DiskImageCache? _disk;

  /// The disk cache, or null on web / in tests / before [init].
  static DiskImageCache? get disk => _disk;

  /// Sets up the disk cache. Call once at startup on Android / iOS.
  static void init({Directory? directory, CachePolicy? cachePolicy}) {
    if (cachePolicy != null) policy = cachePolicy;
    if (kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) return;
    _disk ??= DiskImageCache(
      directory:
          directory ?? Directory('${Directory.systemTemp.path}/myshop_images'),
      policy: policy,
    );
  }

  /// Test hook: install (or remove) a cache.
  @visibleForTesting
  static set diskForTesting(DiskImageCache? cache) => _disk = cache;

  /// The provider for [url] shown [logicalWidth] logical pixels wide.
  static ImageProvider provider(
    String url, {
    double? logicalWidth,
    double devicePixelRatio = 2,
  }) {
    final maxPx = policy.imageDecodeMaxWidth;
    final wantPx =
        (logicalWidth != null && logicalWidth.isFinite && logicalWidth > 0)
        ? (logicalWidth * devicePixelRatio).ceil().clamp(1, maxPx)
        : maxPx;
    final optimized = ImageUrlOptimizer.forWidth(url, wantPx);
    final base = _disk != null
        ? CachedNetworkImage(optimized, _disk!)
        : NetworkImage(optimized) as ImageProvider;
    return ResizeImage(base, width: wantPx, allowUpscaling: false);
  }
}

/// An image that comes from [DiskImageCache].
@immutable
class CachedNetworkImage extends ImageProvider<CachedNetworkImage> {
  const CachedNetworkImage(this.url, this.cache);

  final String url;
  final DiskImageCache cache;

  @override
  Future<CachedNetworkImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<CachedNetworkImage>(this);

  @override
  ImageStreamCompleter loadImage(
    CachedNetworkImage key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _load(key, decode),
      scale: 1,
      debugLabel: url,
    );
  }

  Future<ui.Codec> _load(
    CachedNetworkImage key,
    ImageDecoderCallback decode,
  ) async {
    final bytes = await cache.fetch(key.url);
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Image could not be loaded: ${key.url}');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) =>
      other is CachedNetworkImage && other.url == url;

  @override
  int get hashCode => url.hashCode;
}

/// An [Image] for a network URL that goes through [AppImages]: cached on
/// disk (native), a right-sized download and decode, and a placeholder while
/// loading.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit,
    this.decodeWidth,
    this.placeholder,
    this.errorBuilder,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit? fit;

  /// Logical width to size the download/decode for when [width] is unknown
  /// (a tile that fills its parent).
  final double? decodeWidth;

  /// Shown until the first frame; null shows nothing.
  final Widget? placeholder;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2;
    final w = (width != null && width!.isFinite) ? width : decodeWidth;
    return Image(
      image: AppImages.provider(url, logicalWidth: w, devicePixelRatio: dpr),
      width: width,
      height: height,
      fit: fit,
      errorBuilder: errorBuilder,
      frameBuilder: placeholder == null
          ? null
          : (context, child, frame, sync) =>
                (sync || frame != null) ? child : placeholder!,
    );
  }
}
