import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'cache_policy.dart';

/// Fetches the bytes behind [url], or null when it can not be fetched.
typedef ImageDownloader = Future<Uint8List?> Function(Uri url);

/// A bounded on-disk cache of downloaded images (Android and iOS).
///
///  * identity is the URL: an image whose URL changed is simply a new entry,
///    and the old one ages out;
///  * an image is only kept if it is a real image (checked by its header),
///    complete, and at most `imageMaxFileBytes`; a failed or partial download
///    is never stored, and an older copy is shown if there is one;
///  * entries older than `imageMaxAge` are downloaded again and replaced;
///  * when the total passes `imageCacheBytes` (or `imageMaxEntries`), expired
///    entries go first, then the least recently used, never one being read.
class DiskImageCache {
  DiskImageCache({
    required this.directory,
    CachePolicy? policy,
    ImageDownloader? downloader,
    DateTime Function()? now,
  }) : policy = policy ?? CachePolicy.standard,
       _download = downloader ?? httpDownload,
       _now = now ?? DateTime.now;

  final Directory directory;
  final CachePolicy policy;
  final ImageDownloader _download;
  final DateTime Function() _now;

  final Map<String, _Meta> _index = {};
  final Map<String, Future<Uint8List?>> _inFlight = {};
  final Set<String> _pinned = {};
  Future<void>? _loading;
  Timer? _flushTimer;

  int get totalBytes => _index.values.fold(0, (s, m) => s + m.size);
  int get entryCount => _index.length;

  /// Bytes of [url], from disk when cached and fresh, else downloaded.
  /// Several callers asking for one URL share one download.
  Future<Uint8List?> fetch(String url) {
    return _inFlight[url] ??= _fetch(url).whenComplete(() {
      // A block body on purpose: returning the removed future from here would
      // make this future wait on itself.
      _inFlight.remove(url);
    });
  }

  /// Bytes from disk only (null when not cached, whatever its age).
  Future<Uint8List?> peek(String url) async {
    await _ensureLoaded();
    return _read(_keyOf(url));
  }

  Future<Uint8List?> _fetch(String url) async {
    await _ensureLoaded();
    final key = _keyOf(url);
    final meta = _index[key];
    if (meta != null && !_isExpired(meta)) {
      final bytes = await _read(key);
      if (bytes != null) {
        meta.lastUsed = _now();
        _scheduleFlush();
        return bytes;
      }
    }

    Uint8List? bytes;
    try {
      bytes = await _download(Uri.parse(url));
    } catch (_) {
      bytes = null;
    }
    if (bytes == null || bytes.isEmpty) {
      // Offline or failed: a stale copy is better than nothing.
      return meta != null ? _read(key) : null;
    }
    if (_looksLikeImage(bytes) && bytes.length <= policy.imageMaxFileBytes) {
      await _store(key, url, bytes);
    }
    return bytes;
  }

  Future<void> _store(String key, String url, Uint8List bytes) async {
    try {
      await directory.create(recursive: true);
      final tmp = File('${directory.path}/$key.part');
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(_path(key)); // appears whole or not at all
      _index[key] = _Meta(url, bytes.length, _now(), _now());
      await _evict();
      await _flush();
    } catch (_) {
      // A full disk or a missing folder must never break the screen.
      try {
        await File('${directory.path}/$key.part').delete();
      } catch (_) {}
    }
  }

  Future<void> _evict() async {
    final now = _now();
    for (final k in _index.keys.toList()) {
      if (_isExpired(_index[k]!, now) && !_pinned.contains(k)) await _remove(k);
    }
    while ((totalBytes > policy.imageCacheBytes ||
            _index.length > policy.imageMaxEntries) &&
        _index.isNotEmpty) {
      final candidates =
          _index.entries.where((e) => !_pinned.contains(e.key)).toList()
            ..sort((a, b) => a.value.lastUsed.compareTo(b.value.lastUsed));
      if (candidates.isEmpty) break;
      await _remove(candidates.first.key);
    }
  }

  Future<void> _remove(String key) async {
    _index.remove(key);
    try {
      await File(_path(key)).delete();
    } catch (_) {}
  }

  /// Deletes everything.
  Future<void> clear() async {
    await _ensureLoaded();
    for (final k in _index.keys.toList()) {
      await _remove(k);
    }
    await _flush();
  }

  /// Writes pending usage times to disk.
  Future<void> flush() => _flush();

  bool _isExpired(_Meta m, [DateTime? now]) =>
      (now ?? _now()).difference(m.fetchedAt) > policy.imageMaxAge;

  Future<Uint8List?> _read(String key) async {
    _pinned.add(key);
    try {
      final f = File(_path(key));
      if (!await f.exists()) {
        _index.remove(key);
        return null;
      }
      return await f.readAsBytes();
    } catch (_) {
      return null;
    } finally {
      _pinned.remove(key);
    }
  }

  // ---- index persistence ----------------------------------------------------

  Future<void> _ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    try {
      await directory.create(recursive: true);
      final f = File('${directory.path}/index.json');
      if (await f.exists()) {
        final raw = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        raw.forEach((k, v) {
          final m = _Meta.fromJson(v as Map<String, dynamic>);
          if (File(_path(k)).existsSync()) _index[k] = m;
        });
      }
      // Leftovers of interrupted downloads, and files the index lost.
      for (final e in directory.listSync()) {
        final name = e.uri.pathSegments.last;
        if (e is File &&
            (name.endsWith('.part') ||
                (name.endsWith('.img') &&
                    !_index.containsKey(name.substring(0, name.length - 4))))) {
          try {
            e.deleteSync();
          } catch (_) {}
        }
      }
      await _evict();
    } catch (_) {
      _index.clear();
    }
  }

  void _scheduleFlush() {
    _flushTimer ??= Timer(const Duration(seconds: 5), () {
      _flushTimer = null;
      _flush();
    });
  }

  Future<void> _flush() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    try {
      await directory.create(recursive: true);
      final tmp = File('${directory.path}/index.json.tmp');
      await tmp.writeAsString(
        jsonEncode({for (final e in _index.entries) e.key: e.value.toJson()}),
        flush: true,
      );
      await tmp.rename('${directory.path}/index.json');
    } catch (_) {}
  }

  String _keyOf(String url) => sha1.convert(utf8.encode(url)).toString();
  String _path(String key) => '${directory.path}/$key.img';

  /// JPEG, PNG, GIF or WebP — so an HTML error page is never kept as an image.
  static bool _looksLikeImage(Uint8List b) {
    if (b.length < 12) return false;
    if (b[0] == 0xFF && b[1] == 0xD8) return true; // JPEG
    if (b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) {
      return true; // PNG
    }
    if (b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46) return true; // GIF
    if (b[0] == 0x52 &&
        b[1] == 0x49 &&
        b[2] == 0x46 &&
        b[3] == 0x46 &&
        b[8] == 0x57 &&
        b[9] == 0x45 &&
        b[10] == 0x42 &&
        b[11] == 0x50) {
      return true; // WebP
    }
    return false;
  }

  static const int _hardLimit = 12 * 1024 * 1024;

  /// The real network download (also the default [ImageDownloader]).
  @visibleForTesting
  static Future<Uint8List?> httpDownload(Uri url) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.getUrl(url);
      req.headers.set(HttpHeaders.acceptHeader, 'image/*');
      final res = await req.close().timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) {
        await res.drain<void>();
        return null;
      }
      final expected = res.contentLength;
      final out = BytesBuilder(copy: false);
      await for (final chunk in res.timeout(const Duration(seconds: 30))) {
        out.add(chunk);
        if (out.length > _hardLimit) return null; // not an image we want
      }
      // A body shorter than announced was cut off. Only comparable when the
      // body arrived as sent: for a gzip-compressed response (Firebase Hosting
      // compresses images) the announced length is the compressed size while
      // the bytes handed over are already decompressed, so they never match —
      // there a truncated stream fails while decompressing instead.
      final compressed =
          res.compressionState !=
          HttpClientResponseCompressionState.notCompressed;
      if (!compressed && expected >= 0 && out.length != expected) return null;
      return out.takeBytes();
    } finally {
      client.close(force: true);
    }
  }
}

class _Meta {
  _Meta(this.url, this.size, this.fetchedAt, this.lastUsed);
  final String url;
  final int size;
  final DateTime fetchedAt;
  DateTime lastUsed;

  factory _Meta.fromJson(Map<String, dynamic> j) => _Meta(
    j['u'] as String,
    j['s'] as int,
    DateTime.fromMillisecondsSinceEpoch(j['f'] as int),
    DateTime.fromMillisecondsSinceEpoch(j['l'] as int),
  );

  Map<String, dynamic> toJson() => {
    'u': url,
    's': size,
    'f': fetchedAt.millisecondsSinceEpoch,
    'l': lastUsed.millisecondsSinceEpoch,
  };
}
