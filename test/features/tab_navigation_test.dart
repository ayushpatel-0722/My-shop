import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myshop/app/l10n/app_localizations.dart';
import 'package:myshop/app/l10n/locale_cubit.dart';
import 'package:myshop/app/theme/app_theme.dart';
import 'package:myshop/core/cache/cache_policy.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/app_user.dart';
import 'package:myshop/core/models/category.dart';
import 'package:myshop/core/models/company.dart';
import 'package:myshop/core/models/order.dart';
import 'package:myshop/core/models/product.dart';
import 'package:myshop/core/services/auth_session.dart';
import 'package:myshop/core/services/service_locator.dart';
import 'package:myshop/features/account/account_screen.dart';
import 'package:myshop/features/auth/auth_cubit.dart';
import 'package:myshop/features/checkout/cart/cart_cubit.dart';
import 'package:myshop/features/checkout/cart/wishlist_cubit.dart';
import 'package:myshop/features/checkout/tracking/orders_screen.dart';
import 'package:myshop/features/marketplace/categories/categories_screen.dart';
import 'package:myshop/features/marketplace/home/home_screen.dart';
import 'package:myshop/features/marketplace/widgets/marketplace_shell.dart';

import '../helpers/test_harness.dart';

/// Counts how often each query is opened, so a test can see whether switching
/// tabs asks for the same data again.
class CountingRepo extends MockAppRepository {
  final Map<String, int> calls = {};
  int count(String k) => calls[k] ?? 0;
  void _hit(String k) => calls[k] = count(k) + 1;

  @override
  Stream<List<Category>> categories({String companyId = ''}) {
    _hit('categories');
    return super.categories(companyId: companyId);
  }

  @override
  Stream<List<Company>> companies() {
    _hit('companies');
    return super.companies();
  }

  @override
  Stream<List<Order>> orders({String userId = '', String companyId = ''}) {
    _hit('orders:$userId');
    return super.orders(userId: userId, companyId: companyId);
  }

  @override
  Future<List<Product>> recommendations({String companyId = ''}) {
    _hit('recommendations');
    return super.recommendations(companyId: companyId);
  }
}

/// The real four tabs, in the real stateful shell, with the real bottom bar.
void main() {
  late CountingRepo repo;
  late GoRouter router;

  setUp(() {
    TestHarness.setupPlatformChannels();
    repo = CountingRepo();
    ServiceLocator.instance.repository = repo;
    TestHarness.signIn(TestHarness.shopper);
  });

  tearDown(() {
    TestHarness.signOut();
    RefreshPolicy.homeTtl = const Duration(minutes: 5);
    RefreshPolicy.tabReturnDelay = const Duration(milliseconds: 400);
    MarketplaceTabs.active.value = MarketplaceTabs.home;
  });

  GoRouter shellRouter() => GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MarketplaceShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/categories',
                builder: (_, _) => const CategoriesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/orders', builder: (_, _) => const OrdersScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/account',
                builder: (_, _) => const AccountScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  /// The home page always has something animating: pump for set times.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// [auth] is swapped by the test to simulate switching accounts.
  Future<ValueNotifier<AuthCubit>> openApp(WidgetTester tester) async {
    // The test font is wider than a real one, which overflows a few tight
    // rows; that is not what these tests are about. (Set here, not in setUp:
    // the test binding installs its own handler just before the test body.)
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final auth = ValueNotifier<AuthCubit>(
      AuthCubit.seeded(TestHarness.shopper),
    );
    router = shellRouter();
    await tester.pumpWidget(
      ValueListenableBuilder<AuthCubit>(
        valueListenable: auth,
        builder: (context, cubit, _) => MediaQuery(
          data: const MediaQueryData(size: Size(390, 900)),
          child: MultiBlocProvider(
            providers: [
              BlocProvider<AuthCubit>.value(value: cubit),
              BlocProvider<CartCubit>.value(value: CartCubit()),
              BlocProvider<WishlistCubit>.value(value: WishlistCubit()),
              BlocProvider<LocaleCubit>(create: (_) => LocaleCubit()),
            ],
            child: MaterialApp.router(
              theme: AppTheme.light(),
              locale: const Locale('en'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              routerConfig: router,
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    return auth;
  }

  Future<void> tapTab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar).hitTestable(),
        matching: find.text(label),
      ),
    );
    await settle(tester);
  }

  double homeScroll(WidgetTester tester) => tester
      .state<ScrollableState>(
        find
            .descendant(
              of: find.byType(HomeScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      )
      .position
      .pixels;

  testWidgets(
    'Home → Categories → Home keeps the scroll position and reloads nothing',
    (tester) async {
      await openApp(tester);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await settle(tester);
      final scrolled = homeScroll(tester);
      expect(scrolled, greaterThan(100));
      final categoriesCalls = repo.count('categories');

      await tapTab(tester, 'Categories');
      expect(find.text('Categories & Shops'), findsOneWidget);
      await tapTab(tester, 'Home');

      expect(homeScroll(tester), scrolled, reason: 'scroll position restored');
      expect(find.byType(HomeScreen), findsOneWidget);
      // Opening Categories opened its queries once; nothing was re-opened by
      // coming back to Home.
      expect(repo.count('categories'), greaterThanOrEqualTo(categoriesCalls));
    },
  );

  testWidgets('a tab visited again opens its queries only once', (
    tester,
  ) async {
    await openApp(tester);
    await tapTab(tester, 'Categories');
    final cats = repo.count('categories');
    final comps = repo.count('companies');
    await tapTab(tester, 'Home');
    await tapTab(tester, 'Categories');
    await tapTab(tester, 'Home');
    await tapTab(tester, 'Categories');
    expect(repo.count('categories'), cats);
    expect(repo.count('companies'), comps);
  });

  testWidgets('Orders: loads once, then comes back instantly with its data', (
    tester,
  ) async {
    final placed = await repo.placeOrder(
      Order(
        id: '',
        userId: 'u_1',
        companyId: 'c_organic',
        companyName: 'GreenLeaf Organics',
        items: const [
          OrderItem(productId: 'p1', qty: 1, unitPrice: 50, name: 'Honey'),
        ],
        subtotal: 50,
        totalAmount: 80,
        address: 'A',
        pincode: '380001',
      ),
    );
    await openApp(tester);
    await tapTab(tester, 'Orders');
    expect(find.textContaining(placed.reference), findsWidgets);
    expect(repo.count('orders:u_1'), 1);

    await tapTab(tester, 'Account'); // Settings reads its own order count
    final beforeReturn = repo.count('orders:u_1');
    await tapTab(tester, 'Orders');
    expect(
      find.textContaining(placed.reference),
      findsWidgets,
      reason: 'shown at once',
    );
    expect(
      repo.count('orders:u_1'),
      beforeReturn,
      reason: 'coming back to Orders asks for nothing again',
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('changing the Orders filter does not reopen the orders query', (
    tester,
  ) async {
    await repo.placeOrder(
      Order(
        id: '',
        userId: 'u_1',
        companyId: 'c_organic',
        companyName: 'GreenLeaf Organics',
        items: const [
          OrderItem(productId: 'p1', qty: 1, unitPrice: 50, name: 'Honey'),
        ],
        subtotal: 50,
        totalAmount: 80,
        address: 'A',
        pincode: '380001',
      ),
    );
    await openApp(tester);
    await tapTab(tester, 'Orders');
    expect(repo.count('orders:u_1'), 1);

    // Each tap rebuilds the screen. It used to open the query again every
    // time, which flashed the loader.
    final chips = find.byType(FilterChip);
    expect(chips, findsWidgets);
    await tester.tap(chips.at(1));
    await settle(tester);
    await tester.tap(chips.at(0));
    await settle(tester);

    expect(repo.count('orders:u_1'), 1);
  });

  testWidgets(
    'a page opened over Home: the first tap on Home brings Home back',
    (tester) async {
      await openApp(tester);
      // "See all" in Explore Categories opens the Categories page on top.
      unawaited(router.push('/categories'));
      await settle(tester);
      expect(find.text('Categories & Shops'), findsOneWidget);

      // Home is not the tab on screen, but it is the tab the shell is on: the
      // tap used to do nothing.
      await tapTab(tester, 'Home');
      expect(
        find.text('Categories & Shops'),
        findsNothing,
        reason: 'the page is gone and Home shows',
      );
      expect(find.byType(HomeScreen), findsOneWidget);
    },
  );

  testWidgets('the Categories tab has no back arrow in its app bar', (
    tester,
  ) async {
    await openApp(tester);
    await tapTab(tester, 'Categories');
    expect(find.text('Categories & Shops'), findsOneWidget);
    final appBar = find.descendant(
      of: find.byType(CategoriesScreen),
      matching: find.byType(AppBar),
    );
    expect(appBar, findsOneWidget);
    expect(
      find.descendant(of: appBar, matching: find.byType(BackButton)),
      findsNothing,
    );
    expect(
      find.descendant(of: appBar, matching: find.byIcon(Icons.arrow_back)),
      findsNothing,
    );
    expect(tester.widget<AppBar>(appBar).automaticallyImplyLeading, isFalse);
  });

  testWidgets('"See all" opens the Categories tab, also without a back arrow', (
    tester,
  ) async {
    await openApp(tester);
    await tester.tap(find.text('See All').first);
    await settle(tester);
    expect(find.text('Categories & Shops'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets("the phone's Back button on Categories returns to Home", (
    tester,
  ) async {
    await openApp(tester);
    await tapTab(tester, 'Categories');
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text('Categories & Shops'), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('from "See all" the first tap on Home works', (tester) async {
    await openApp(tester);
    await tester.tap(find.text('See All').first);
    await settle(tester);
    await tapTab(tester, 'Home');
    expect(find.text('Categories & Shops'), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('the other tabs still work from a page opened over Home', (
    tester,
  ) async {
    await openApp(tester);
    unawaited(router.push('/categories'));
    await settle(tester);
    await tapTab(tester, 'Account');
    expect(find.byType(AccountScreen), findsOneWidget);
  });

  testWidgets('Settings (Account) does not touch Home or Orders data', (
    tester,
  ) async {
    await openApp(tester);
    final before = Map<String, int>.of(repo.calls);
    await tapTab(tester, 'Account');
    // Settings reads its own counts (orders, vouchers), but must not touch
    // what Home and Categories already loaded.
    for (final key in ['categories', 'companies', 'recommendations']) {
      expect(repo.count(key), before[key] ?? 0, reason: '$key reopened');
    }
  });

  testWidgets('rapid tab switching does not refetch anything', (tester) async {
    await openApp(tester);
    await tapTab(tester, 'Categories');
    await tapTab(tester, 'Orders');
    await tapTab(tester, 'Account');
    await tapTab(tester, 'Home');
    final before = Map<String, int>.of(repo.calls);
    for (var i = 0; i < 4; i++) {
      for (final t in ['Categories', 'Orders', 'Account', 'Home']) {
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar).hitTestable(),
            matching: find.text(t),
          ),
        );
        await tester.pump(const Duration(milliseconds: 30));
      }
    }
    await settle(tester);
    expect(repo.calls, before);
  });

  testWidgets('a new order shows up in Orders while it is in the background', (
    tester,
  ) async {
    await openApp(tester);
    await tapTab(tester, 'Orders');
    await tapTab(tester, 'Home');
    final fresh = await repo.placeOrder(
      Order(
        id: '',
        userId: 'u_1',
        companyId: 'c_organic',
        companyName: 'GreenLeaf Organics',
        items: const [
          OrderItem(productId: 'p9', qty: 1, unitPrice: 70, name: 'FreshJam'),
        ],
        subtotal: 70,
        totalAmount: 100,
        address: 'A',
        pincode: '380001',
      ),
    );
    await settle(tester);
    await tapTab(tester, 'Orders');
    expect(find.textContaining(fresh.reference), findsWidgets);
    expect(repo.count('orders:u_1'), 1, reason: 'live update, no reload');
  });

  testWidgets('Orders do not leak to another account', (tester) async {
    final ashas = await repo.placeOrder(
      Order(
        id: '',
        userId: 'u_1',
        companyId: 'c_organic',
        companyName: 'GreenLeaf Organics',
        items: const [
          OrderItem(
            productId: 'p1',
            qty: 1,
            unitPrice: 50,
            name: 'AshaOnlyItem',
          ),
        ],
        subtotal: 50,
        totalAmount: 80,
        address: 'A',
        pincode: '380001',
      ),
    );
    final auth = await openApp(tester);
    await tapTab(tester, 'Orders');
    expect(find.textContaining(ashas.reference), findsWidgets);

    // Another shopper signs in on the same device.
    const other = AppUser(
      id: 'u_2',
      name: 'Ravi',
      mobileNumber: '9000000000',
      role: 'user',
    );
    AuthSession.set(other);
    auth.value = AuthCubit.seeded(other);
    await settle(tester);

    expect(
      find.textContaining(ashas.reference),
      findsNothing,
      reason: 'not shown to Ravi',
    );
    expect(repo.count('orders:u_2'), 1, reason: 'his own orders were loaded');
    expect(repo.count('orders:u_1'), 1);
  });

  testWidgets(
    'returning to Home refreshes stale data once, however fast the taps',
    (tester) async {
      RefreshPolicy.homeTtl = Duration.zero; // everything counts as stale
      RefreshPolicy.tabReturnDelay = const Duration(milliseconds: 200);
      await openApp(tester);
      final before = repo.count('recommendations');
      expect(before, greaterThanOrEqualTo(1));

      Future<void> quickTap(String label) async {
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar).hitTestable(),
            matching: find.text(label),
          ),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }

      // Eight quick taps: four visits back to Home, well inside the delay.
      for (var i = 0; i < 4; i++) {
        await quickTap('Categories');
        await quickTap('Home');
      }
      expect(repo.count('recommendations'), before, reason: 'nothing yet');

      await tester.pump(const Duration(milliseconds: 400)); // delay passes
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      expect(
        repo.count('recommendations') - before,
        1,
        reason: 'one request for the whole burst, not one per visit',
      );
    },
  );

  testWidgets('with fresh data returning to Home asks nothing', (tester) async {
    RefreshPolicy.tabReturnDelay = const Duration(milliseconds: 20);
    await openApp(tester);
    final before = repo.count('recommendations');
    await tapTab(tester, 'Categories');
    await tapTab(tester, 'Home');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    expect(repo.count('recommendations'), before);
  });
}
