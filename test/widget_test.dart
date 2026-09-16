import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:myshop/core/services/service_locator.dart';
import 'package:myshop/main.dart';

void main() {
  testWidgets('app builds without crashing', (WidgetTester tester) async {
    ServiceLocator.instance.init(firebaseReady: false);

    await tester.pumpWidget(const Bootstrap(firebaseReady: false));
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
