import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:myshop/app/routes/app_router.dart';

import 'package:myshop/app/l10n/app_localizations.dart';
import 'package:myshop/app/theme/app_theme.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/models/app_user.dart';
import 'package:myshop/core/services/auth_session.dart';
import 'package:myshop/core/services/service_locator.dart';
import 'package:myshop/features/auth/auth_cubit.dart';
import 'package:myshop/features/checkout/cart/cart_cubit.dart';
import 'package:myshop/features/checkout/cart/wishlist_cubit.dart';

/// Shared wiring for the widget tests.
///
/// Every screen in this app reads its data from the global [repo] getter and
/// its actor from [AuthCubit] / `AuthSession`. This harness installs a fresh
/// in-memory repository, mocks the platform channels the code touches and
/// builds a `MaterialApp` with the real localizations + theme.
abstract class TestHarness {
  /// Installs a fresh [MockAppRepository] and returns it.
  static MockAppRepository useMockRepository() {
    final repository = MockAppRepository();
    ServiceLocator.instance.repository = repository;
    return repository;
  }

  /// Boots the whole [ServiceLocator] (connectivity, deep links, reports).
  ///
  /// Required by screens that gate critical writes on `connectivity`.
  static MockAppRepository bootServiceLocator() {
    ServiceLocator.instance.init(firebaseReady: false);
    final repository = MockAppRepository();
    ServiceLocator.instance.repository = repository;
    return repository;
  }

  /// Mocks the platform channels used by the tested screens.
  ///
  /// Without this, `connectivity_plus` throws `MissingPluginException`.
  static void setupPlatformChannels() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/connectivity'),
          (call) async => <String>['wifi'],
        );
  }

  /// Signs [user] in for both the router guards and the admin shell.
  static void signIn(AppUser? user) => AuthSession.set(user, restoring: false);

  /// Clears the session between tests.
  static void signOut() => AuthSession.set(null, restoring: false);

  /// Admin of `GreenLeaf Organics` (company id `c_organic`).
  static const AppUser admin = AppUser(
    id: 'a_1',
    companyId: 'c_organic',
    companyName: 'GreenLeaf Organics',
    name: 'Admin GreenLeaf',
    email: 'admin@greenleaf.in',
    role: 'admin',
  );

  /// Admin of a **different** store, used to prove tenant isolation.
  static const AppUser otherAdmin = AppUser(
    id: 'a_2',
    companyId: 'c_techtronics',
    companyName: 'TechTronics Hub',
    name: 'Admin TechTronics',
    email: 'admin@techtronics.in',
    role: 'admin',
  );

  /// Regular shopper (no saved addresses — checkout must ask for one).
  static const AppUser shopper = AppUser(
    id: 'u_1',
    name: 'Asha Shopper',
    mobileNumber: '9876543210',
    role: 'user',
  );

  /// Saved home address used by the checkout tests (pincode 380001 -> ₹30).
  static const AddressEntry homeAddress = AddressEntry(
    id: 'addr_home',
    name: 'Asha Shopper',
    phone: '9876543210',
    houseNo: '12',
    address: 'Market Street',
    city: 'Ahmedabad',
    state: 'Gujarat',
    pincode: '380001',
    isDefault: true,
    label: 'Home',
  );

  /// Second saved address (non-default) for selection tests.
  static const AddressEntry workAddress = AddressEntry(
    id: 'addr_work',
    name: 'Asha Shopper',
    phone: '9876543210',
    houseNo: '4',
    address: 'Trade Road',
    city: 'Ahmedabad',
    state: 'Gujarat',
    pincode: '380009',
    label: 'Work',
  );

  /// The shopper with saved addresses, as the checkout reads them from the
  /// profile (`AppUser.addresses`, max 3).
  static final AppUser shopperWithAddresses = shopper.copyWith(
    addresses: const [homeAddress, workAddress],
  );

  static const AppUser employee = AppUser(
    id: 'e_1',
    companyId: 'c_organic',
    companyName: 'GreenLeaf Organics',
    name: 'Ramesh Packer',
    email: 'packer@greenleaf.in',
    role: 'employee',
    employeeRole: 'Picker',
  );
}

/// A minimal router so screens that call `context.go(...)` behave exactly like
/// they do in the app (the checkout navigates to the placed order).
GoRouter buildTestRouter(
  Widget child, {
  String initialLocation = '/',
  List<GoRoute> extraRoutes = const <GoRoute>[],
}) => GoRouter(
  initialLocation: initialLocation,
  errorBuilder: (context, state) =>
      Scaffold(body: Center(child: Text('Route error: ${state.uri}'))),
  routes: <RouteBase>[
    GoRoute(path: '/', builder: (context, state) => child),
    ...extraRoutes,
    GoRoute(
      path: AppRoutes.orders,
      builder: (context, state) =>
          const Scaffold(body: Center(child: Text('Orders screen'))),
    ),
    GoRoute(
      path: AppRoutes.orderTracking,
      builder: (context, state) => Scaffold(
        body: Center(child: Text('Order ${state.pathParameters['id']}')),
      ),
    ),
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) =>
          const Scaffold(body: Center(child: Text('Home screen'))),
    ),
    GoRoute(
      path: AppRoutes.cart,
      builder: (context, state) =>
          const Scaffold(body: Center(child: Text('Cart screen'))),
    ),
    GoRoute(
      path: AppRoutes.categories,
      builder: (context, state) =>
          const Scaffold(body: Center(child: Text('Categories screen'))),
    ),
    GoRoute(
      path: AppRoutes.category,
      builder: (context, state) => Scaffold(
        body: Center(child: Text('Category ${state.pathParameters['id']}')),
      ),
    ),
    GoRoute(
      path: AppRoutes.product,
      builder: (context, state) => Scaffold(
        body: Center(child: Text('Product ${state.pathParameters['id']}')),
      ),
    ),
    GoRoute(
      path: AppRoutes.adminAddProduct,
      builder: (context, state) =>
          const Scaffold(body: Center(child: Text('Add product screen'))),
    ),
    GoRoute(
      path: AppRoutes.adminAddCategory,
      builder: (context, state) =>
          const Scaffold(body: Center(child: Text('Add category screen'))),
    ),
    GoRoute(
      path: AppRoutes.adminEditProduct,
      builder: (context, state) => Scaffold(
        body: Center(child: Text('Edit product ${state.pathParameters['id']}')),
      ),
    ),
    GoRoute(
      path: AppRoutes.adminEditCategory,
      builder: (context, state) => Scaffold(
        body: Center(
          child: Text('Edit category ${state.pathParameters['id']}'),
        ),
      ),
    ),
    GoRoute(
      path: AppRoutes.reviews,
      builder: (context, state) => Scaffold(
        body: Center(
          child: Text('Reviews ${state.pathParameters['companyId']}'),
        ),
      ),
    ),
    GoRoute(
      path: AppRoutes.leaveReview,
      builder: (context, state) => Scaffold(
        body: Center(
          child: Text(
            'Leave review ${state.pathParameters['orderId']} '
            'rating=${state.uri.queryParameters['rating'] ?? ''}',
          ),
        ),
      ),
    ),
    GoRoute(
      path: AppRoutes.search,
      builder: (context, state) => Scaffold(
        body: Center(
          child: Text(
            'Search companyId=${state.uri.queryParameters['companyId'] ?? ''}',
          ),
        ),
      ),
    ),
    GoRoute(
      path: AppRoutes.account,
      builder: (context, state) =>
          const Scaffold(body: Center(child: Text('Account screen'))),
    ),
  ],
);

/// Builds a themed, localized app around [child] with the BLoCs the screens
/// expect.
///
/// Pass [user] to pre-authenticate (uses `AuthCubit.seeded`, which skips the
/// platform dependent session restore).
Widget buildTestApp(
  Widget child, {
  AppUser? user,
  AuthCubit? authCubit,
  CartCubit? cartCubit,
  WishlistCubit? wishlistCubit,
  Size size = const Size(1200, 2400),
  bool withRouter = true,
}) {
  final shell = MediaQuery(
    data: MediaQueryData(size: size),
    child: MultiBlocProvider(
      providers: [
        if (authCubit != null)
          BlocProvider<AuthCubit>.value(value: authCubit)
        else if (user != null)
          BlocProvider<AuthCubit>.value(value: AuthCubit.seeded(user)),
        BlocProvider<CartCubit>.value(value: cartCubit ?? CartCubit()),
        BlocProvider<WishlistCubit>.value(
          value: wishlistCubit ?? WishlistCubit(),
        ),
      ],
      child: child,
    ),
  );

  if (withRouter) {
    return MaterialApp.router(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: buildTestRouter(shell),
    );
  }

  return MaterialApp(
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: shell,
  );
}

/// Pumps [child] inside [buildTestApp] and waits for the first frame.
Future<void> pumpTestApp(
  WidgetTester tester,
  Widget child, {
  AppUser? user,
  AuthCubit? authCubit,
  CartCubit? cartCubit,
  WishlistCubit? wishlistCubit,
  Size size = const Size(1200, 2400),
}) async {
  await tester.pumpWidget(
    buildTestApp(
      child,
      user: user,
      authCubit: authCubit,
      cartCubit: cartCubit,
      wishlistCubit: wishlistCubit,
      size: size,
    ),
  );
  await tester.pumpAndSettle();
}
