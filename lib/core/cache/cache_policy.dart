/// How fresh a kind of data has to be, which decides how long an idle shared
/// stream keeps listening and how long its last value may be replayed.
enum DataClass {
  /// Rarely changes: categories, shops, banners, delivery rules.
  reference,

  /// Product listings and home configuration.
  catalog,

  /// Changes often or is business-critical: vouchers, reviews.
  volatile,
}

/// One place for every cache limit, so they can be tuned (and tested)
/// without hunting through the app.
///
/// Sizes were chosen from the real data: 100 products plus categories and
/// banners are a few hundred KB of Firestore documents, product photos are
/// 15-300 KB each once resized, and a shopper browses a few dozen per visit.
class CachePolicy {
  // ---- Firestore's own on-device cache (the data cache) -------------------
  /// Size above which Firestore evicts its least recently used documents.
  /// Applies on Android, iOS, and on the web once the shopper allowed caching.
  final int firestoreCacheBytes;

  // ---- Image disk cache (Android / iOS; browsers cache images themselves) --
  /// Total bytes the image cache may use before evicting.
  final int imageCacheBytes;

  /// Largest single image that is stored; bigger ones are shown but not kept.
  final int imageMaxFileBytes;

  /// Maximum number of stored images.
  final int imageMaxEntries;

  /// An image older than this is downloaded again (and replaced).
  final Duration imageMaxAge;

  /// Images are decoded no wider than this many pixels.
  final int imageDecodeMaxWidth;

  // ---- In-memory shared streams -------------------------------------------
  /// Most distinct queries remembered at once; the least recently used go.
  final int maxSharedEntries;

  /// How long an unused query keeps its live listener, and how long its last
  /// value may still be shown (then refreshed) after the listener is gone.
  final Map<DataClass, Duration> keepAlive;
  final Map<DataClass, Duration> maxAge;

  const CachePolicy({
    this.firestoreCacheBytes = 40 * 1024 * 1024,
    this.imageCacheBytes = 60 * 1024 * 1024,
    this.imageMaxFileBytes = 1536 * 1024,
    this.imageMaxEntries = 400,
    this.imageMaxAge = const Duration(days: 14),
    this.imageDecodeMaxWidth = 800,
    this.maxSharedEntries = 64,
    this.keepAlive = const {
      DataClass.reference: Duration(minutes: 2),
      DataClass.catalog: Duration(seconds: 60),
      DataClass.volatile: Duration(seconds: 15),
    },
    this.maxAge = const {
      DataClass.reference: Duration(hours: 24),
      DataClass.catalog: Duration(hours: 6),
      DataClass.volatile: Duration(minutes: 10),
    },
  });

  static const CachePolicy standard = CachePolicy();

  Duration keepAliveFor(DataClass c) =>
      keepAlive[c] ?? const Duration(minutes: 1);
  Duration maxAgeFor(DataClass c) => maxAge[c] ?? const Duration(hours: 1);
}

/// When data shown from memory is refreshed in the background.
///
/// Live (streamed) data refreshes itself; these rules are for data fetched
/// once. Business-critical values (prices, stock, order status) are always
/// re-read from the server when they matter, at checkout and when an order
/// changes, whatever these say.
class RefreshPolicy {
  const RefreshPolicy._();

  /// After switching back to a tab, wait this long before refreshing it, so
  /// tapping quickly through the tabs asks the server once, not per tap.
  static Duration tabReturnDelay = const Duration(milliseconds: 400);

  /// Home recommendations: change slowly, cheap to reuse.
  static Duration homeTtl = const Duration(minutes: 5);
}
