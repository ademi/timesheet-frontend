import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:rostiq/app/router/app_go_router.dart';
import 'package:rostiq/app/router/go_router_params.dart';
import 'package:rostiq/app/router/go_router_redirect.dart';
import 'package:rostiq/app/routes/app_navigator.dart';
import 'package:rostiq/app/routes/app_routes.dart';
import 'package:rostiq/core/services/token_storage.dart';

String _fakeJwt(Map<String, dynamic> payload) {
  final header = base64Url.encode(
    utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})),
  );
  final body = base64Url.encode(utf8.encode(jsonEncode(payload)));
  return '$header.$body.signature';
}

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

  group('appGoRouterRedirect', () {
    test('sends unauthenticated users away from protected routes', () async {
      final storage = TokenStorage();
      Get.put<TokenStorage>(storage);

      final redirect = appGoRouterRedirect(
        _FakeContext(),
        _FakeGoRouterState(AppRoutes.staffHome),
      );
      expect(redirect, AppRoutes.gateway);
    });

    test('allows unauthenticated users onto public auth entry', () async {
      final storage = TokenStorage();
      Get.put<TokenStorage>(storage);

      expect(
        appGoRouterRedirect(
          _FakeContext(),
          _FakeGoRouterState(AppRoutes.login),
        ),
        isNull,
      );
      expect(
        appGoRouterRedirect(
          _FakeContext(),
          _FakeGoRouterState(AppRoutes.gateway),
        ),
        isNull,
      );
      expect(
        appGoRouterRedirect(
          _FakeContext(),
          _FakeGoRouterState(
            '${AppRoutes.contractorRegister}/NfbL--92RGctMTm7',
          ),
        ),
        isNull,
      );
    });

    test('staff may open contractor invite register deep link', () async {
      final storage = TokenStorage();
      await storage.persistTokens(
        accessToken: _fakeJwt({
          'exp':
              DateTime.now()
                  .add(const Duration(hours: 1))
                  .millisecondsSinceEpoch ~/
              1000,
          'actor_type': 'tenant_member',
        }),
        refreshToken: 'refresh',
      );
      Get.put<TokenStorage>(storage);

      expect(
        appGoRouterRedirect(
          _FakeContext(),
          _FakeGoRouterState(
            '${AppRoutes.contractorRegister}/invite-token-abc',
          ),
        ),
        isNull,
      );
    });

    test('forces first-login when mcp claim is set', () async {
      final storage = TokenStorage();
      await storage.persistTokens(
        accessToken: _fakeJwt({
          'exp':
              DateTime.now()
                  .add(const Duration(hours: 1))
                  .millisecondsSinceEpoch ~/
              1000,
          'mcp': true,
          'actor_type': 'tenant_member',
        }),
        refreshToken: 'refresh',
      );
      Get.put<TokenStorage>(storage);

      expect(
        appGoRouterRedirect(
          _FakeContext(),
          _FakeGoRouterState(AppRoutes.staffHome),
        ),
        AppRoutes.firstLogin,
      );
    });

    test('blocks contractor opening staff home', () async {
      final storage = TokenStorage();
      await storage.persistTokens(
        accessToken: _fakeJwt({
          'exp':
              DateTime.now()
                  .add(const Duration(hours: 1))
                  .millisecondsSinceEpoch ~/
              1000,
          'actor_type': 'contractor',
        }),
        refreshToken: 'refresh',
      );
      Get.put<TokenStorage>(storage);

      expect(
        appGoRouterRedirect(
          _FakeContext(),
          _FakeGoRouterState(AppRoutes.staffHome),
        ),
        AppRoutes.wrongActor,
      );
    });
  });

  group('createAppGoRouter Phase-1 routes', () {
    testWidgets('boots at gateway and can go to login', (tester) async {
      final storage = TokenStorage();
      Get.put<TokenStorage>(storage);

      final router = createAppGoRouter(initialLocation: AppRoutes.gateway);
      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router),
      );
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        AppRoutes.gateway,
      );

      router.go(AppRoutes.login);
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        AppRoutes.login,
      );
    });

    testWidgets('contractor invite token path stays on register when logged out', (
      tester,
    ) async {
      final storage = TokenStorage();
      Get.put<TokenStorage>(storage);

      const token = 'NfbL--92RGctMTm7M42KYB3W7ZXsUc9KQnFZQzdkC4A';
      final invitePath = '${AppRoutes.contractorRegister}/$token';
      final router = GoRouter(
        initialLocation: invitePath,
        redirect: appGoRouterRedirect,
        routes: [
          GoRoute(
            path: AppRoutes.gateway,
            builder: (_, __) => const Text('gateway'),
          ),
          GoRoute(
            path: AppRoutes.contractorRegisterWithToken,
            builder: (context, state) {
              syncGetxFromGoRouterState(state);
              return Text('register:${state.pathParameters['token']}');
            },
          ),
        ],
      );
      AppNavigator.bindWebRouter(router);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('register:$token'), findsOneWidget);
      expect(find.text('gateway'), findsNothing);
      expect(Get.parameters['token'], token);
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        invitePath,
      );
    });

    testWidgets('unknown path redirects unauthenticated users to gateway', (
      tester,
    ) async {
      final storage = TokenStorage();
      Get.put<TokenStorage>(storage);

      final router = createAppGoRouter(
        initialLocation: '/staff/clients/detail',
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        AppRoutes.gateway,
      );
    });

    testWidgets('unknown path shows placeholder when authenticated', (
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
        }),
        refreshToken: 'refresh',
      );
      Get.put<TokenStorage>(storage);

      final router = createAppGoRouter(
        initialLocation: '/staff/clients/not-migrated-yet',
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.byType(UnknownRoutePage), findsOneWidget);
      expect(find.text('Page not found'), findsOneWidget);
    });
  });
}

class _FakeContext extends Fake implements BuildContext {}

class _FakeGoRouterState extends Fake implements GoRouterState {
  _FakeGoRouterState(this._matchedLocation);

  final String _matchedLocation;

  @override
  String get matchedLocation => _matchedLocation;
}
