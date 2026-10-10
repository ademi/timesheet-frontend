import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:rostiq/app/router/go_router_params.dart';

void main() {
  tearDown(Get.reset);

  testWidgets('syncGetxFromGoRouterState drops sticky keys not on the route', (
    tester,
  ) async {
    Get.parameters['id'] = 'shift-old';
    Get.parameters['clientId'] = 'c-old';

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const SizedBox()),
        GoRoute(
          path: '/compose',
          builder: (context, state) {
            syncGetxFromGoRouterState(state);
            return const SizedBox();
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.go('/compose?clientId=c-new');
    await tester.pumpAndSettle();

    expect(Get.parameters.containsKey('id'), isFalse);
    expect(Get.parameters['clientId'], 'c-new');
  });

  testWidgets('syncGetxFromGoRouterState mirrors extra ids into Get.parameters', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const SizedBox()),
        GoRoute(
          path: '/sil-detail',
          builder: (context, state) {
            syncGetxFromGoRouterState(state);
            return const SizedBox();
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    // ignore: unawaited_futures
    router.push('/sil-detail', extra: {'house_id': 'house-99'});
    await tester.pump();

    expect(Get.parameters['house_id'], 'house-99');
    expect(Get.arguments, isA<Map>());
    expect((Get.arguments as Map)['house_id'], 'house-99');
  });
}
