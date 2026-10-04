import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:rostiq/app/router/app_go_router.dart';
import 'package:rostiq/app/routes/app_navigator.dart';
import 'package:rostiq/app/routes/app_routes.dart';
import 'package:rostiq/app/routes/middlewares/auth_route_utils.dart';
import 'package:rostiq/core/services/token_storage.dart';

String _fakeJwt(Map<String, dynamic> payload) {
  final header = base64Url.encode(
    utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})),
  );
  final body = base64Url.encode(utf8.encode(jsonEncode(payload)));
  return '$header.$body.signature';
}

/// Phase 6.8 — cold-start `initialLocation` smoke (widget-level; no Chrome driver).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.testMode = true;
    Get.reset();
    FlutterSecureStorage.setMockInitialValues({});
    AppNavigator.debugUnbindWebRouter();
  });

  tearDown(() {
    AppNavigator.debugUnbindWebRouter();
    Get.reset();
  });

  testWidgets('cold initialLocation keeps path + id query', (tester) async {
    final router = GoRouter(
      initialLocation: '${AppRoutes.staffVisitDetail}?id=visit-smoke-1',
      routes: [
        GoRoute(
          path: AppRoutes.staffVisitDetail,
          builder: (context, state) {
            Get.parameters
              ..clear()
              ..addAll(state.uri.queryParameters);
            return Text('visit:${state.uri.queryParameters['id']}');
          },
        ),
      ],
    );
    AppNavigator.bindWebRouter(router);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('visit:visit-smoke-1'), findsOneWidget);
    expect(
      locationPath(AppNavigator.currentLocation),
      AppRoutes.staffVisitDetail,
    );
    expect(AppNavigator.queryParameters['id'], 'visit-smoke-1');
    expect(routeParam('id'), 'visit-smoke-1');
  });

  testWidgets('unknown path CTA returns authenticated user off unknown page', (
    tester,
  ) async {
    final storage = TokenStorage();
    await storage.persistTokens(
      accessToken: _fakeJwt({
        'exp':
            DateTime.now()
                .add(const Duration(hours: 1))
                .millisecondsSinceEpoch ~/
            1000,
        'actor_type': 'tenant_member',
        'permissions': ['*'],
      }),
      refreshToken: 'refresh',
    );
    Get.put<TokenStorage>(storage);

    final router = createAppGoRouter(
      initialLocation: '/staff/this-route-does-not-exist',
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.byType(UnknownRoutePage), findsOneWidget);
    expect(find.text('Page not found'), findsOneWidget);

    await tester.tap(find.text('Go to home'));
    await tester.pumpAndSettle();

    expect(find.byType(UnknownRoutePage), findsNothing);
  });
}
