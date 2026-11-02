import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/utils/cart_notification.dart';
import 'package:myshop/core/widgets/app_toast.dart';

import '../helpers/test_harness.dart';

void main() {
  setUp(TestHarness.setupPlatformChannels);

  Future<BuildContext> pump(WidgetTester tester) async {
    await pumpTestApp(tester, const Scaffold(body: SizedBox()));
    return tester.element(find.byType(Scaffold).first);
  }

  testWidgets('a toast with an action still hides after 3 seconds', (
    tester,
  ) async {
    final context = await pump(tester);
    AppToast.success(context, 'Saved', actionLabel: 'UNDO', onAction: () {});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('UNDO'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 3000));
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('a hand-built SnackBar with an action is normalized to 3s', (
    tester,
  ) async {
    final context = await pump(tester);
    ScaffoldMessenger.of(context).showAppToast(
      SnackBar(
        content: const Text('Old style'),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(label: 'GO', onPressed: () {}),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Old style'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Old style'), findsNothing);
  });

  testWidgets('a new toast replaces the current one instead of queueing', (
    tester,
  ) async {
    final context = await pump(tester);
    AppToast.info(context, 'first');
    AppToast.error(context, 'second');
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('first'), findsNothing);
    expect(find.text('second'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('add to cart toast shows once, then hides after 3 seconds', (
    tester,
  ) async {
    final context = await pump(tester);
    showAddToCartNotification(context, productName: 'Oak Chair');
    showAddToCartNotification(
      context,
      productName: 'Oak Chair',
      variantLabel: 'Walnut',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.byKey(const Key('add-to-cart-success-snackbar')),
      findsOneWidget,
    );
    expect(find.textContaining('Walnut'), findsOneWidget);
    expect(find.text('VIEW CART'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add-to-cart-success-snackbar')), findsNothing);
  });
}
