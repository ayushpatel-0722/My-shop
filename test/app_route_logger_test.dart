import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:myshop/core/utils/app_route_logger.dart';

void main() {
  group('AppRouteLogger', () {
    test('logs push and pop transitions with route names', () {
      final logger = AppRouteLogger();
      final logs = <String>[];

      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        logs.add(message ?? '');
      };

      addTearDown(() {
        debugPrint = originalDebugPrint;
      });

      final homeRoute = MaterialPageRoute(
        builder: (_) => const SizedBox(),
        settings: const RouteSettings(name: '/home'),
      );
      final searchRoute = MaterialPageRoute(
        builder: (_) => const SizedBox(),
        settings: const RouteSettings(name: '/search'),
      );

      logger.didPush(searchRoute, homeRoute);
      logger.didPop(searchRoute, homeRoute);

      expect(logs.first, contains('[ROUTE PUSH]'));
      expect(logs.first, contains('(/home)  --->  SearchScreen (/search)'));
      expect(logs.last, contains('[ROUTE POP]'));
      expect(logs.last, contains('(/search)  <---  HomeScreen (/home)'));
    });
  });
}
