import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/cache/cache_policy.dart';
import 'package:myshop/core/cache/disk_image_cache.dart';

Uint8List jpeg(int size, [int seed = 0]) {
  final b = Uint8List(size);
  b[0] = 0xFF;
  b[1] = 0xD8;
  for (var i = 2; i < size; i++) {
    b[i] = (i + seed) & 0xFF;
  }
  return b;
}

void main() {
  httpDownloaderTests();

  late Directory dir;
  late Map<String, Uint8List?> server;
  late List<String> downloads;
  var now = DateTime(2026, 1, 1);

  DiskImageCache make({CachePolicy? policy, Directory? d}) => DiskImageCache(
    directory: d ?? dir,
    policy: policy,
    now: () => now,
    downloader: (uri) async {
      downloads.add(uri.toString());
      return server[uri.toString()];
    },
  );

  setUp(() {
    dir = Directory.systemTemp.createTempSync('img_cache_test');
    server = {};
    downloads = [];
    now = DateTime(2026, 1, 1);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('an image is downloaded once, then served from disk', () async {
    server['https://x/a.jpg'] = jpeg(1000);
    final c = make();
    final first = await c.fetch('https://x/a.jpg');
    final second = await c.fetch('https://x/a.jpg');
    expect(first, jpeg(1000));
    expect(second, jpeg(1000));
    expect(downloads.length, 1);
    expect(c.entryCount, 1);
    expect(c.totalBytes, 1000);
  });

  test('it survives a restart (a new cache over the same folder)', () async {
    server['https://x/a.jpg'] = jpeg(500);
    await make().fetch('https://x/a.jpg');
    final again = make();
    expect(await again.fetch('https://x/a.jpg'), jpeg(500));
    expect(downloads.length, 1, reason: 'no second download');
  });

  test('simultaneous requests share one download', () async {
    server['https://x/a.jpg'] = jpeg(300);
    final c = make();
    final r = await Future.wait([
      for (var i = 0; i < 5; i++) c.fetch('https://x/a.jpg'),
    ]);
    expect(r.every((b) => b != null), isTrue);
    expect(downloads.length, 1);
  });

  test('an old image is downloaded again and replaced', () async {
    server['https://x/a.jpg'] = jpeg(400, 1);
    final c = make();
    await c.fetch('https://x/a.jpg');
    now = now.add(const Duration(days: 15));
    server['https://x/a.jpg'] = jpeg(450, 2); // the source changed
    final fresh = await c.fetch('https://x/a.jpg');
    expect(fresh, jpeg(450, 2));
    expect(downloads.length, 2);
    expect(c.totalBytes, 450, reason: 'the old copy was replaced');
  });

  test('a changed URL is a new entry', () async {
    server['https://x/a.jpg'] = jpeg(100);
    server['https://x/a-v2.jpg'] = jpeg(120);
    final c = make();
    await c.fetch('https://x/a.jpg');
    await c.fetch('https://x/a-v2.jpg');
    expect(downloads.length, 2);
    expect(c.entryCount, 2);
  });

  test(
    'a failed download shows the old copy if there is one, else nothing',
    () async {
      final c = make();
      expect(await c.fetch('https://x/none.jpg'), isNull);
      expect(c.entryCount, 0);

      server['https://x/a.jpg'] = jpeg(200);
      await c.fetch('https://x/a.jpg');
      now = now.add(const Duration(days: 20));
      server['https://x/a.jpg'] = null; // offline now
      expect(await c.fetch('https://x/a.jpg'), jpeg(200));
    },
  );

  test('broken or non-image responses are shown never stored', () async {
    server['https://x/err'] = Uint8List.fromList(
      List<int>.generate(100, (i) => 0x3C), // "<<<<…" like an HTML page
    );
    final c = make();
    await c.fetch('https://x/err');
    expect(c.entryCount, 0);
    expect(dir.listSync().where((f) => f.path.endsWith('.img')), isEmpty);
  });

  test('an image above the per-file limit is not kept', () async {
    server['https://x/big.jpg'] = jpeg(5000);
    final c = make(policy: const CachePolicy(imageMaxFileBytes: 4000));
    final bytes = await c.fetch('https://x/big.jpg');
    expect(bytes, isNotNull, reason: 'still shown');
    expect(c.entryCount, 0);
  });

  test(
    'the total stays within the limit; least recently used go first',
    () async {
      final c = make(policy: const CachePolicy(imageCacheBytes: 2500));
      for (final n in ['a', 'b', 'c']) {
        server['https://x/$n.jpg'] = jpeg(1000);
        await c.fetch('https://x/$n.jpg');
        now = now.add(const Duration(minutes: 1));
      }
      // Total 3000 > 2500 → the oldest ("a") was evicted.
      expect(c.totalBytes, lessThanOrEqualTo(2500));
      expect(await c.peek('https://x/a.jpg'), isNull);
      expect(await c.peek('https://x/b.jpg'), isNotNull);

      // Using "b" makes it recent: the next newcomer evicts "c" instead.
      await c.fetch('https://x/b.jpg');
      now = now.add(const Duration(minutes: 1));
      server['https://x/d.jpg'] = jpeg(1000);
      await c.fetch('https://x/d.jpg');
      expect(c.totalBytes, lessThanOrEqualTo(2500));
      expect(await c.peek('https://x/c.jpg'), isNull);
      expect(await c.peek('https://x/b.jpg'), isNotNull);
    },
  );

  test('the number of entries is bounded too', () async {
    final c = make(policy: const CachePolicy(imageMaxEntries: 2));
    for (final n in ['a', 'b', 'c']) {
      server['https://x/$n.jpg'] = jpeg(100);
      await c.fetch('https://x/$n.jpg');
      now = now.add(const Duration(minutes: 1));
    }
    expect(c.entryCount, 2);
  });

  test('expired entries are removed before others when making room', () async {
    final c = make(policy: const CachePolicy(imageCacheBytes: 2100));
    server['https://x/old.jpg'] = jpeg(1000);
    await c.fetch('https://x/old.jpg');
    now = now.add(const Duration(days: 10));
    server['https://x/mid.jpg'] = jpeg(1000);
    await c.fetch('https://x/mid.jpg');
    now = now.add(const Duration(days: 6)); // "old" is now 16 days old: expired
    await c.fetch('https://x/old.jpg'); // used, but expired → re-downloaded
    server['https://x/new.jpg'] = jpeg(1000);
    await c.fetch('https://x/new.jpg');
    expect(c.totalBytes, lessThanOrEqualTo(2100));
  });

  test(
    'half-written downloads and orphan files are cleaned on start',
    () async {
      File('${dir.path}/abc.part').writeAsBytesSync([1, 2, 3]);
      File('${dir.path}/orphan.img').writeAsBytesSync(jpeg(50));
      final c = make();
      await c.peek('https://x/whatever');
      expect(File('${dir.path}/abc.part').existsSync(), isFalse);
      expect(File('${dir.path}/orphan.img').existsSync(), isFalse);
    },
  );

  test('a corrupt index is ignored, not fatal', () async {
    File('${dir.path}/index.json').writeAsStringSync('{ not json');
    server['https://x/a.jpg'] = jpeg(100);
    final c = make();
    expect(await c.fetch('https://x/a.jpg'), isNotNull);
  });

  test('a folder that can not be written never breaks the fetch', () async {
    final blocked = File('${dir.path}/file');
    blocked.writeAsStringSync('x'); // a file where the folder should be
    server['https://x/a.jpg'] = jpeg(100);
    final c = make(d: Directory('${blocked.path}/sub'));
    expect(await c.fetch('https://x/a.jpg'), jpeg(100));
    expect(c.entryCount, 0);
  });

  test('clear empties the cache', () async {
    server['https://x/a.jpg'] = jpeg(100);
    final c = make();
    await c.fetch('https://x/a.jpg');
    await c.clear();
    expect(c.entryCount, 0);
    expect(dir.listSync().where((f) => f.path.endsWith('.img')), isEmpty);
  });
}

/// The real downloader against a local server that behaves like Firebase
/// Hosting (which gzips images) and like a connection that drops mid-image.
void httpDownloaderTests() {
  group('real HTTP download', () {
    late HttpServer server;
    late Uint8List image;

    setUp(() async {
      image = jpeg(40000);
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        final res = req.response;
        switch (req.uri.path) {
          case '/plain.jpg':
            res.headers.contentType = ContentType('image', 'jpeg');
            res.headers.contentLength = image.length;
            res.add(image);
          case '/gzip.jpg':
            // Hosting sends the image gzipped: Content-Length is the
            // compressed size, which differs from the image size.
            final gz = gzip.encode(image);
            res.headers.contentType = ContentType('image', 'jpeg');
            res.headers.set(HttpHeaders.contentEncodingHeader, 'gzip');
            res.headers.contentLength = gz.length;
            res.add(gz);
          default:
            res.statusCode = 404;
        }
        await res.close();
      });
    });
    tearDown(() => server.close(force: true));

    Future<Uint8List?> get(String path) => DiskImageCache.httpDownload(
      Uri.parse('http://127.0.0.1:${server.port}$path'),
    );

    test('a plain image comes back whole', () async {
      expect(await get('/plain.jpg'), image);
    });

    test(
      'a gzip-compressed image comes back whole (Firebase Hosting)',
      () async {
        expect(await get('/gzip.jpg'), image);
      },
    );

    test('a missing image is not an image', () async {
      expect(await get('/nope.jpg'), isNull);
    });

    test('an image cut short is rejected', () async {
      // A raw server: promises 40000 bytes, sends 1000, hangs up.
      final raw = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => raw.close());
      raw.listen((socket) async {
        socket.listen((_) {});
        socket.add(
          'HTTP/1.1 200 OK\r\nContent-Type: image/jpeg\r\n'
                  'Content-Length: 40000\r\n\r\n'
              .codeUnits,
        );
        socket.add(image.sublist(0, 1000));
        await socket.flush();
        await socket.close();
      });
      Uint8List? got;
      try {
        got = await DiskImageCache.httpDownload(
          Uri.parse('http://127.0.0.1:${raw.port}/x.jpg'),
        );
      } catch (_) {
        got = null; // the hang-up may also surface as an error
      }
      expect(got, isNull);
    });

    test('and a compressed image is cached and served from disk', () async {
      final dir = Directory.systemTemp.createTempSync('gz_cache');
      addTearDown(() => dir.deleteSync(recursive: true));
      final cache = DiskImageCache(directory: dir);
      final url = 'http://127.0.0.1:${server.port}/gzip.jpg';
      expect(await cache.fetch(url), image);
      expect(cache.entryCount, 1);
      await server.close(force: true); // offline now
      expect(await cache.fetch(url), image, reason: 'from disk');
    });
  });
}
