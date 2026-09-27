import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:rostiq/app/constants/app_permissions.dart';
import 'package:rostiq/app/router/billing_go_routes.dart';
import 'package:rostiq/app/router/contractor_onboarding_go_routes.dart';
import 'package:rostiq/app/router/credentials_go_routes.dart';
import 'package:rostiq/app/router/engagements_go_routes.dart';
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

void _collectPaths(List<RouteBase> routes, Set<String> paths) {
  for (final r in routes) {
    if (r is GoRoute) {
      paths.add(r.path);
      _collectPaths(r.routes, paths);
    } else if (r is ShellRoute) {
      _collectPaths(r.routes, paths);
    }
  }
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

  group('Phase 5 route registration', () {
    test('engagements routes cover invite/detail/rate-form', () {
      final paths = <String>{};
      _collectPaths(
        buildEngagementsGoRoutes(
          rootNavigatorKey: GlobalKey<NavigatorState>(),
        ),
        paths,
      );
      expect(paths, contains(AppRoutes.staffWorkforceInvite));
      expect(paths, contains(AppRoutes.staffWorkforceDetail));
      expect(paths, contains('rate-form'));
    });

    test('credentials routes cover create/detail/review', () {
      final paths = <String>{};
      _collectPaths(buildCredentialsGoRoutes(), paths);
      expect(paths, contains(AppRoutes.contractorCredentialCreate));
      expect(paths, contains(AppRoutes.contractorCredentialDetail));
      expect(paths, contains(AppRoutes.staffCredentialReview));
    });

    test('billing routes cover export detail', () {
      final paths = <String>{};
      _collectPaths(buildBillingGoRoutes(), paths);
      expect(paths, contains(AppRoutes.staffBillingExportDetail));
    });

    test('contractor onboarding routes cover funnel + complete-account', () {
      final paths = <String>{};
      _collectPaths(buildContractorOnboardingGoRoutes(), paths);
      expect(paths, contains(AppRoutes.contractorOnboarding));
      expect(paths, contains(AppRoutes.contractorOnboardingLegal));
      expect(paths, contains(AppRoutes.contractorOnboardingNotices));
      expect(paths, contains(AppRoutes.contractorOnboardingConsents));
      expect(paths, contains(AppRoutes.contractorOnboardingEngagement));
      expect(paths, contains(AppRoutes.contractorOnboardingCredentials));
      expect(paths, contains(AppRoutes.contractorCompleteAccount));
    });
  });

  group('Phase 5 permission redirects', () {
    test('workforce invite denies without contractorsInvite', () async {
      await _putStaffToken(permissions: [AppPermissions.contractorsRead]);
      final denied = redirectMissingPermission(
        route: AppRoutes.staffWorkforceInvite,
        anyOf: const [AppPermissions.contractorsInvite],
        showToast: false,
      );
      expect(denied?.name, AppRoutes.staffHome);
    });

    test('credential review allows with credentialsRead', () async {
      await _putStaffToken(permissions: [AppPermissions.credentialsRead]);
      expect(
        redirectMissingPermission(
          route: AppRoutes.staffCredentialReview,
          anyOf: const [
            AppPermissions.credentialsRead,
            AppPermissions.credentialsReview,
          ],
          showToast: false,
        ),
        isNull,
      );
    });
  });

  group('Phase 5 URL hydrate stubs', () {
    testWidgets('workforce detail keeps ?id=', (tester) async {
      final router = GoRouter(
        initialLocation: AppRoutes.staffWorkforce,
        routes: [
          GoRoute(
            path: AppRoutes.staffWorkforce,
            builder: (_, __) => const Text('list'),
          ),
          GoRoute(
            path: AppRoutes.staffWorkforceDetail,
            builder: (context, state) {
              Get.parameters
                ..clear()
                ..addAll(state.uri.queryParameters);
              return Text('detail:${state.uri.queryParameters['id']}');
            },
          ),
        ],
      );
      AppNavigator.bindWebRouter(router);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      AppNavigator.push(
        AppNavigator.location(
          AppRoutes.staffWorkforceDetail,
          query: {'id': 'e1'},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('detail:e1'), findsOneWidget);
      expect(routeParam('id'), 'e1');
    });

    testWidgets('billing exports ?tab= reaches location', (tester) async {
      final router = GoRouter(
        initialLocation: AppRoutes.staffHome,
        routes: [
          GoRoute(
            path: AppRoutes.staffHome,
            builder: (_, __) => const Text('home'),
          ),
          GoRoute(
            path: AppRoutes.staffBillingExports,
            builder: (context, state) {
              Get.parameters
                ..clear()
                ..addAll(state.uri.queryParameters);
              return Text('billing:${state.uri.queryParameters['tab']}');
            },
          ),
        ],
      );
      AppNavigator.bindWebRouter(router);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      AppNavigator.push(
        AppNavigator.location(
          AppRoutes.staffBillingExports,
          query: {'tab': 'burn'},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('billing:burn'), findsOneWidget);
      expect(routeParam('tab'), 'burn');
    });
  });
}
