import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:rostiq/app/constants/app_permissions.dart';
import 'package:rostiq/app/router/clients_go_routes.dart';
import 'package:rostiq/app/router/go_router_redirect.dart';
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

Future<void> _putStaffToken({List<String> permissions = const []}) async {
  final storage = TokenStorage();
  await storage.persistTokens(
    accessToken: _fakeJwt({
      'exp':
          DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
          1000,
      'actor_type': 'tenant_member',
      if (permissions.isNotEmpty) 'permissions': permissions,
    }),
    refreshToken: 'refresh',
  );
  Get.put<TokenStorage>(storage);
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

  group('Phase 3 public invites', () {
    test('isGoRouterPublicLocation allows invite token paths', () {
      expect(isGoRouterPublicLocation('/invites/client/abc'), isTrue);
      expect(isGoRouterPublicLocation('/invite/legacy-token'), isTrue);
      expect(isGoRouterPublicLocation(AppRoutes.staffClientDetail), isFalse);
    });

    test('unauthenticated users may open public invite locations', () async {
      final storage = TokenStorage();
      Get.put<TokenStorage>(storage);

      expect(
        appGoRouterRedirect(
          _FakeContext(),
          _FakeGoRouterState('/invites/client/tok'),
        ),
        isNull,
      );
      expect(
        appGoRouterRedirect(
          _FakeContext(),
          _FakeGoRouterState('/invite/legacy'),
        ),
        isNull,
      );
    });
  });

  group('Phase 3 client route registration', () {
    test('buildClientsGoRoutes covers detail/onboarding/forms/invites', () {
      final routes = buildClientsGoRoutes().whereType<GoRoute>().toList();
      final paths = routes.map((r) => r.path).toSet();
      expect(paths, contains(AppRoutes.staffClientDetail));
      expect(paths, contains(AppRoutes.staffClientOnboarding));
      expect(paths, contains(AppRoutes.staffClientForm));
      expect(paths, contains(AppRoutes.staffClientSupportPlan));
      expect(paths, contains(AppRoutes.staffClientStrengthsNeeds));
      expect(paths, contains(AppRoutes.staffClientSiteForm));
      expect(paths, contains(AppRoutes.staffClientContactForm));
      expect(paths, contains(AppRoutes.publicClientInvite));
      expect(paths, contains(AppRoutes.publicClientInviteLegacy));
      expect(paths.contains(AppRoutes.staffClients), isFalse);
    });
  });

  group('Phase 3 permission redirects', () {
    test('clientsManage route denies without claim', () async {
      await _putStaffToken(permissions: [AppPermissions.clientsRead]);
      final denied = redirectMissingPermission(
        route: AppRoutes.staffClientOnboarding,
        anyOf: const [AppPermissions.clientsManage],
        showToast: false,
      );
      expect(denied?.name, AppRoutes.staffHome);
    });

    test('clientsManage route allows with claim', () async {
      await _putStaffToken(
        permissions: [
          AppPermissions.clientsRead,
          AppPermissions.clientsManage,
        ],
      );
      final denied = redirectMissingPermission(
        route: AppRoutes.staffClientOnboarding,
        anyOf: const [AppPermissions.clientsManage],
        showToast: false,
      );
      expect(denied, isNull);
    });
  });

  group('Phase 3 routeParam + onboarding URL', () {
    testWidgets('routeParam reads go_router query after bind', (tester) async {
      await _putStaffToken(
        permissions: [
          AppPermissions.clientsRead,
          AppPermissions.clientsManage,
        ],
      );

      final router = GoRouter(
        initialLocation: '${AppRoutes.staffClientOnboarding}?id=c1&step=2',
        routes: [
          GoRoute(
            path: AppRoutes.staffClientOnboarding,
            builder: (context, state) {
              Get.parameters
                ..clear()
                ..addAll(state.uri.queryParameters);
              return const Text('onboarding-stub');
            },
          ),
        ],
      );
      AppNavigator.bindWebRouter(router);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('onboarding-stub'), findsOneWidget);
      expect(routeParam('id'), 'c1');
      expect(routeParam('step'), '2');
      expect(
        locationPath(AppNavigator.currentLocation),
        AppRoutes.staffClientOnboarding,
      );
      expect(AppNavigator.queryParameters['step'], '2');
    });

    testWidgets('AppNavigator.replace keeps onboarding step in URL', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '${AppRoutes.staffClientOnboarding}?step=0',
        routes: [
          GoRoute(
            path: AppRoutes.staffClientOnboarding,
            builder: (_, __) => const Text('onboarding'),
          ),
        ],
      );
      AppNavigator.bindWebRouter(router);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      AppNavigator.replace(
        AppNavigator.location(
          AppRoutes.staffClientOnboarding,
          query: {'id': 'c9', 'step': '3'},
        ),
      );
      await tester.pumpAndSettle();

      expect(AppNavigator.queryParameters['id'], 'c9');
      expect(AppNavigator.queryParameters['step'], '3');
      expect(find.text('onboarding'), findsOneWidget);
    });

    testWidgets('public invite path stays off gateway when logged out', (
      tester,
    ) async {
      final storage = TokenStorage();
      Get.put<TokenStorage>(storage);

      final router = GoRouter(
        initialLocation: '/invites/client/test-token',
        redirect: appGoRouterRedirect,
        routes: [
          GoRoute(
            path: AppRoutes.gateway,
            builder: (_, __) => const Text('gateway'),
          ),
          GoRoute(
            path: AppRoutes.publicClientInvite,
            builder: (context, state) {
              Get.parameters['token'] = state.pathParameters['token'] ?? '';
              return Text('invite:${state.pathParameters['token']}');
            },
          ),
        ],
      );
      AppNavigator.bindWebRouter(router);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('invite:test-token'), findsOneWidget);
      expect(find.text('gateway'), findsNothing);
      expect(routeParam('token'), 'test-token');
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
