import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/app/l10n/app_localizations.dart';
import 'package:myshop/app/theme/app_theme.dart';
import 'package:myshop/features/auth/auth_cubit.dart';
import 'package:myshop/features/checkout/cart/cart_cubit.dart';
import 'package:myshop/features/checkout/cart/wishlist_cubit.dart';
import 'package:myshop/features/marketplace/home/home_screen.dart';
import 'package:myshop/features/marketplace/widgets/section_header.dart';

import '../helpers/test_harness.dart';

void main() {
  late AuthCubit authCubit;
  late CartCubit cartCubit;
  late WishlistCubit wishlistCubit;

  setUp(() {
    TestHarness.setupPlatformChannels();
    TestHarness.useMockRepository();
    TestHarness.signIn(TestHarness.shopper);
    authCubit = AuthCubit();
    cartCubit = CartCubit();
    wishlistCubit = WishlistCubit();
  });

  tearDown(() {
    authCubit.close();
    cartCubit.close();
    wishlistCubit.close();
    TestHarness.signOut();
  });

  Widget buildTestWidget({required Widget child, ThemeData? theme}) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>.value(value: authCubit),
        BlocProvider<CartCubit>.value(value: cartCubit),
        BlocProvider<WishlistCubit>.value(value: wishlistCubit),
      ],
      child: MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: theme ?? AppTheme.light(),
        home: child,
      ),
    );
  }

  group('Store Voucher Deals See All Modal & Dialog', () {
    testWidgets(
      'Mobile view: Tapping See All opens styled bottom sheet with surface color and active coupons',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(buildTestWidget(child: const HomeScreen()));
        await tester.pumpAndSettle();

        // 1. Verify "Store Vouchers & Deals" section exists
        final vouchersHeader = find.text('Store Vouchers & Deals');
        expect(vouchersHeader, findsOneWidget);

        // 2. Find the "See All" button corresponding to Store Vouchers & Deals
        final vouchersSectionHeader = find.ancestor(
          of: vouchersHeader,
          matching: find.byType(SectionHeader),
        );
        final seeAllInVouchers = find.descendant(
          of: vouchersSectionHeader,
          matching: find.text('See All'),
        );
        expect(seeAllInVouchers, findsOneWidget);

        await tester.tap(seeAllInVouchers);
        await tester.pumpAndSettle();

        // 3. Verify bottom sheet modal opened
        // Header title
        expect(find.text('All Active Coupons'), findsOneWidget);
        expect(find.text('Tap copy to apply code at checkout'), findsOneWidget);

        // Drag handle bar exists in mobile sheet
        expect(find.byType(DraggableScrollableSheet), findsOneWidget);

        // Vouchers should be visible in sheet
        expect(
          find.descendant(
            of: find.byType(DraggableScrollableSheet),
            matching: find.text('FRESH20'),
          ),
          findsOneWidget,
        );

        // Verify the container has surface/white decoration, NOT black/empty
        final sheetContainer = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(DraggableScrollableSheet),
                matching: find.byType(Container),
              )
              .first,
        );
        final decoration = sheetContainer.decoration as BoxDecoration?;
        expect(decoration, isNotNull);
        expect(decoration!.color, equals(Colors.white));

        // 4. Test Copy button interaction inside sheet
        final copyButtonInSheet = find
            .descendant(
              of: find.byType(DraggableScrollableSheet),
              matching: find.text('COPY'),
            )
            .first;
        await tester.tap(copyButtonInSheet);
        await tester.pumpAndSettle();

        // One of the buttons should now display 'COPIED'
        expect(
          find.descendant(
            of: find.byType(DraggableScrollableSheet),
            matching: find.text('COPIED'),
          ),
          findsOneWidget,
        );

        // 5. Test close button
        final closeButton = find.byIcon(Icons.close_rounded);
        expect(closeButton, findsOneWidget);
        await tester.tap(closeButton);
        await tester.pumpAndSettle();

        // Sheet should be dismissed
        expect(find.text('All Active Coupons'), findsNothing);
      },
    );

    testWidgets(
      'Desktop Web view: Tapping See All opens responsive centered Dialog instead of bottom sheet',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(buildTestWidget(child: const HomeScreen()));
        await tester.pumpAndSettle();

        // 1. Verify "Store Vouchers & Deals" section exists
        final vouchersHeader = find.text('Store Vouchers & Deals');
        expect(vouchersHeader, findsOneWidget);

        final vouchersSectionHeader = find.ancestor(
          of: vouchersHeader,
          matching: find.byType(SectionHeader),
        );
        final seeAllInVouchers = find.descendant(
          of: vouchersSectionHeader,
          matching: find.text('See All'),
        );
        expect(seeAllInVouchers, findsOneWidget);

        // 2. Tap See All
        await tester.tap(seeAllInVouchers);
        await tester.pumpAndSettle();

        // 3. Verify centered Dialog is opened (NOT DraggableScrollableSheet)
        expect(find.byType(Dialog), findsOneWidget);
        expect(find.byType(DraggableScrollableSheet), findsNothing);

        // Check title and voucher content in dialog
        expect(find.text('All Active Coupons'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(Dialog),
            matching: find.text('FRESH20'),
          ),
          findsOneWidget,
        );

        // Verify Dialog container is constrained to maxWidth 580
        final dialogContainer = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(Dialog),
                matching: find.byType(Container),
              )
              .first,
        );
        expect(dialogContainer.constraints?.maxWidth, equals(580));
        final decoration = dialogContainer.decoration as BoxDecoration?;
        expect(decoration, isNotNull);
        expect(decoration!.color, equals(Colors.white));

        // 4. Test close button on Dialog
        final closeBtn = find.byIcon(Icons.close_rounded);
        expect(closeBtn, findsOneWidget);
        await tester.tap(closeBtn);
        await tester.pumpAndSettle();

        // Dialog should be dismissed
        expect(find.byType(Dialog), findsNothing);
      },
    );
  });
}
