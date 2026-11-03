import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/app/l10n/app_localizations.dart';
import 'package:myshop/core/cache/cache_consent.dart';
import 'package:myshop/core/cache/cache_consent_controller.dart';
import 'package:myshop/core/cache/storage_persistence.dart';
import 'package:myshop/core/widgets/cache_consent_prompt.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakePersistence implements StoragePersistenceApi {
  FakePersistence(this.result);
  PersistenceResult result;
  int requests = 0;
  @override
  Future<bool?> isPersisted() async => null;
  @override
  Future<PersistenceResult> request() async {
    requests++;
    if (result == PersistenceResult.error) throw StateError('blocked');
    return result;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('CacheConsentStore', () {
    test('nothing stored means undecided', () async {
      expect(await CacheConsentStore().read(), CacheConsent.undecided);
    });

    test('remembers allowed and declined', () async {
      final s = CacheConsentStore();
      await s.write(CacheConsent.allowed);
      expect(await CacheConsentStore().read(), CacheConsent.allowed);
      await s.write(CacheConsent.declined);
      expect(await CacheConsentStore().read(), CacheConsent.declined);
    });

    test('an answer to an older policy version is asked again', () async {
      SharedPreferences.setMockInitialValues({
        'cache_consent': 'allowed:${CacheConsentStore.policyVersion - 1}',
      });
      expect(await CacheConsentStore().read(), CacheConsent.undecided);
    });

    test('garbage counts as undecided', () async {
      SharedPreferences.setMockInitialValues({'cache_consent': 'maybe'});
      expect(await CacheConsentStore().read(), CacheConsent.undecided);
      SharedPreferences.setMockInitialValues({'cache_consent': 'yes:1'});
      expect(await CacheConsentStore().read(), CacheConsent.undecided);
    });

    test('writing undecided clears the answer', () async {
      final s = CacheConsentStore();
      await s.write(CacheConsent.allowed);
      await s.write(CacheConsent.undecided);
      expect(await s.read(), CacheConsent.undecided);
    });
  });

  group('CacheConsentPrompt', () {
    final dialog = find.byKey(const Key('cache-consent-dialog'));
    final allow = find.byKey(const Key('cache-consent-allow'));
    final notNow = find.byKey(const Key('cache-consent-not-now'));

    CacheConsentController controller({
      required CacheConsent initial,
      bool isWeb = true,
      FakePersistence? persistence,
      List<CacheConsent>? applied,
    }) => CacheConsentController(
      initial: initial,
      isWeb: isWeb,
      store: CacheConsentStore(),
      persistence: persistence ?? FakePersistence(PersistenceResult.granted),
      onApply: (c) => applied?.add(c),
    );

    Future<void> pump(WidgetTester tester, CacheConsentController c) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) =>
              CacheConsentPrompt(controller: c, child: child!),
          home: const Scaffold(body: Center(child: Text('ROLE SCREEN'))),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'first visit on the web: the app is there, the question over it',
      (tester) async {
        final applied = <CacheConsent>[];
        final c = controller(initial: CacheConsent.undecided, applied: applied)
          ..start();
        await pump(tester, c);

        expect(find.text('ROLE SCREEN'), findsOneWidget, reason: 'app loaded');
        expect(dialog, findsOneWidget, reason: 'asked over the app');
        expect(applied, [CacheConsent.undecided], reason: 'nothing kept yet');
      },
    );

    testWidgets(
      'it says which kinds of data are stored, like a cookie notice',
      (tester) async {
        await pump(tester, controller(initial: CacheConsent.undecided));
        expect(find.text('Cookies & saved data'), findsOneWidget);
        expect(find.text('Essential (always on)'), findsOneWidget);
        expect(find.textContaining('signed in'), findsOneWidget);
        expect(find.text('Saved data for faster loading'), findsOneWidget);
        expect(find.textContaining('product images'), findsOneWidget);
        expect(find.textContaining('40 MB'), findsOneWidget);
        expect(
          find.textContaining('Passwords and payment details'),
          findsOneWidget,
        );
        expect(find.text('Allow all'), findsOneWidget);
        expect(find.text('Only essential'), findsOneWidget);
      },
    );

    testWidgets('the app underneath can not be tapped while it is open', (
      tester,
    ) async {
      await pump(tester, controller(initial: CacheConsent.undecided));
      expect(find.byType(ModalBarrier), findsWidgets);
    });

    testWidgets(
      'Allow: stored, persistence requested, prompt gone, app still there',
      (tester) async {
        final p = FakePersistence(PersistenceResult.granted);
        final applied = <CacheConsent>[];
        final c = controller(
          initial: CacheConsent.undecided,
          persistence: p,
          applied: applied,
        );
        await pump(tester, c);
        await tester.tap(allow);
        await settle(tester);

        expect(p.requests, 1);
        expect(applied, [CacheConsent.allowed]);
        expect(dialog, findsNothing);
        expect(find.text('ROLE SCREEN'), findsOneWidget);
        expect(await CacheConsentStore().read(), CacheConsent.allowed);
      },
    );

    testWidgets('Only essential: stored, browser NOT asked, prompt gone', (
      tester,
    ) async {
      final p = FakePersistence(PersistenceResult.granted);
      final applied = <CacheConsent>[];
      final c = controller(
        initial: CacheConsent.undecided,
        persistence: p,
        applied: applied,
      );
      await pump(tester, c);
      await tester.tap(notNow);
      await settle(tester);

      expect(p.requests, 0);
      expect(applied, [CacheConsent.declined]);
      expect(dialog, findsNothing);
      expect(await CacheConsentStore().read(), CacheConsent.declined);
    });

    for (final result in [
      PersistenceResult.denied,
      PersistenceResult.unsupported,
      PersistenceResult.error,
    ]) {
      testWidgets('Allow still counts when the browser says $result', (
        tester,
      ) async {
        final applied = <CacheConsent>[];
        final c = controller(
          initial: CacheConsent.undecided,
          persistence: FakePersistence(result),
          applied: applied,
        );
        await pump(tester, c);
        await tester.tap(allow);
        await settle(tester);
        expect(applied, [CacheConsent.allowed]);
        expect(dialog, findsNothing);
      });
    }

    testWidgets('an earlier answer: no prompt at all', (tester) async {
      for (final stored in [CacheConsent.allowed, CacheConsent.declined]) {
        final p = FakePersistence(PersistenceResult.granted);
        final applied = <CacheConsent>[];
        final c = controller(initial: stored, persistence: p, applied: applied)
          ..start();
        await pump(tester, c);
        expect(dialog, findsNothing);
        expect(find.text('ROLE SCREEN'), findsOneWidget);
        expect(applied, [stored]);
        expect(p.requests, 0);
      }
    });

    testWidgets('after clearing browser data the question is asked again', (
      tester,
    ) async {
      final store = CacheConsentStore();
      await store.write(CacheConsent.allowed);
      SharedPreferences.setMockInitialValues({}); // site data cleared
      final c = controller(initial: await store.read());
      await pump(tester, c);
      expect(dialog, findsOneWidget);
      expect(find.text('ROLE SCREEN'), findsOneWidget);
    });

    testWidgets('Android / iOS: never asks', (tester) async {
      final applied = <CacheConsent>[];
      final c = controller(
        initial: CacheConsent.undecided,
        isWeb: false,
        applied: applied,
      )..start();
      await pump(tester, c);
      expect(dialog, findsNothing);
      expect(applied, [CacheConsent.allowed]);
    });

    testWidgets('a double tap asks the browser only once', (tester) async {
      final p = FakePersistence(PersistenceResult.granted);
      await pump(
        tester,
        controller(initial: CacheConsent.undecided, persistence: p),
      );
      await tester.tap(allow);
      await tester.tap(allow, warnIfMissed: false);
      await settle(tester);
      expect(p.requests, 1);
    });

    testWidgets('no controller (tests, mock mode): just the app', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CacheConsentPrompt(child: Scaffold(body: Text('APP'))),
        ),
      );
      expect(find.text('APP'), findsOneWidget);
      expect(dialog, findsNothing);
    });
  });
}
