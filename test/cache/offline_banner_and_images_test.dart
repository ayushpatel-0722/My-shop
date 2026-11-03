import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/app/l10n/app_localizations.dart';
import 'package:myshop/core/cache/app_images.dart';
import 'package:myshop/core/cache/disk_image_cache.dart';
import 'package:myshop/core/widgets/offline_banner.dart';

Widget host(Widget child) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: Scaffold(body: child),
);

void main() {
  group('OfflineBanner', () {
    testWidgets('shows nothing while online', (tester) async {
      await tester.pumpWidget(
        host(
          OfflineBanner(
            checkConnectivity: () async => true,
            changes: const Stream<bool>.empty(),
            child: const Text('CONTENT'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('CONTENT'), findsOneWidget);
      expect(find.byKey(const Key('offline-banner')), findsNothing);
    });

    testWidgets('says it is showing saved data when offline, and clears', (
      tester,
    ) async {
      final ctl = StreamController<bool>();
      addTearDown(ctl.close);
      await tester.pumpWidget(
        host(
          OfflineBanner(
            checkConnectivity: () async => false,
            changes: ctl.stream,
            child: const Text('CONTENT'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('You are offline. Showing saved data.'), findsOneWidget);
      expect(find.text('CONTENT'), findsOneWidget);

      ctl.add(true);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('offline-banner')), findsNothing);
    });

    testWidgets('no connectivity information never shows a false offline', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          OfflineBanner(
            checkConnectivity: () async => throw StateError('no plugin'),
            child: const Text('CONTENT'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('offline-banner')), findsNothing);
    });
  });

  group('AppImages', () {
    tearDown(() => AppImages.diskForTesting = null);

    test('without a disk cache (web, tests) it uses the network provider', () {
      AppImages.diskForTesting = null;
      final p = AppImages.provider('https://x/a.jpg', logicalWidth: 100);
      expect(p, isA<ResizeImage>());
      final inner = (p as ResizeImage).imageProvider;
      expect(inner, isA<NetworkImage>());
    });

    test('with a disk cache it goes through the cache', () {
      final dir = Directory.systemTemp.createTempSync('ai');
      addTearDown(() => dir.deleteSync(recursive: true));
      AppImages.diskForTesting = DiskImageCache(
        directory: dir,
        downloader: (_) async => Uint8List(0),
      );
      final p = AppImages.provider('https://x/a.jpg', logicalWidth: 100);
      expect((p as ResizeImage).imageProvider, isA<CachedNetworkImage>());
    });

    test('decode width follows the widget, capped by the policy', () {
      AppImages.diskForTesting = null;
      final small =
          AppImages.provider(
                'https://x/a.jpg',
                logicalWidth: 60,
                devicePixelRatio: 3,
              )
              as ResizeImage;
      expect(small.width, 180);
      final huge =
          AppImages.provider(
                'https://x/a.jpg',
                logicalWidth: 5000,
                devicePixelRatio: 3,
              )
              as ResizeImage;
      expect(huge.width, AppImages.policy.imageDecodeMaxWidth);
      final unknown = AppImages.provider('https://x/a.jpg') as ResizeImage;
      expect(unknown.width, AppImages.policy.imageDecodeMaxWidth);
    });

    test('a Wikimedia thumbnail is asked for at a size that fits', () {
      const url =
          'https://thumb.wikimedia.org/wikipedia/commons/thumb/c/cc/A.jpg/1920px-A.jpg';
      final p =
          AppImages.provider(url, logicalWidth: 80, devicePixelRatio: 2)
              as ResizeImage;
      final net = p.imageProvider as NetworkImage;
      expect(net.url, contains('/250px-A.jpg'));
    });

    test(
      'providers for the same URL are equal so Flutter reuses the decode',
      () {
        final dir = Directory.systemTemp.createTempSync('ai2');
        addTearDown(() => dir.deleteSync(recursive: true));
        final cache = DiskImageCache(
          directory: dir,
          downloader: (_) async => null,
        );
        expect(CachedNetworkImage('u', cache), CachedNetworkImage('u', cache));
        expect(
          CachedNetworkImage('u', cache),
          isNot(CachedNetworkImage('v', cache)),
        );
      },
    );
  });
}
