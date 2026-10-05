import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:rostiq/app/constants/app_permissions.dart';
import 'package:rostiq/app/router/jobs_go_routes.dart';
import 'package:rostiq/app/router/visits_go_routes.dart';
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

  group('Phase 4 route registration', () {
    test('buildVisitsGoRoutes covers detail + group wizards', () {
      final rootKey = GlobalKey<NavigatorState>();
      final top = buildVisitsGoRoutes(rootNavigatorKey: rootKey);
      final paths = <String>{};
      void walk(List<RouteBase> routes) {
        for (final r in routes) {
          if (r is GoRoute) {
            paths.add(r.path);
            walk(r.routes);
          } else if (r is ShellRoute) {
            walk(r.routes);
          }
        }
      }

      walk(top);
      expect(paths, contains(AppRoutes.staffVisitDetail));
      expect(paths, contains(AppRoutes.staffShiftDetail));
      expect(paths, contains(AppRoutes.staffGroupShiftBook));
      expect(paths, contains('edit-group'));
      expect(paths, contains('remove-participant'));
      expect(paths, contains('participant-attendance'));
      expect(paths, contains('publish-group'));
      expect(paths, contains('travel'));
    });

    test('buildJobsGoRoutes covers detail + compose + templates', () {
      final paths =
          buildJobsGoRoutes().whereType<GoRoute>().map((r) => r.path).toSet();
      expect(paths, contains(AppRoutes.staffJobDetail));
      expect(paths, contains(AppRoutes.staffJobForm));
      expect(paths, contains(AppRoutes.staffRosterCompose));
      expect(paths, contains(AppRoutes.staffUnifiedSupport));
      expect(paths, contains(AppRoutes.staffOngoingSupport));
      expect(paths, contains(AppRoutes.staffFormTemplates));
      expect(paths, contains(AppRoutes.staffJobManageTemplates));
      expect(paths, contains(AppRoutes.staffFormTemplateEditor));
      expect(paths, contains(AppRoutes.staffRecurrenceRuleForm));
      expect(paths.contains(AppRoutes.staffJobs), isFalse);
    });
  });

  group('Phase 4 permission redirects', () {
    test('visit detail denies without claim', () async {
      await _putStaffToken(permissions: [AppPermissions.authSession]);
      final denied = redirectMissingPermission(
        route: AppRoutes.staffVisitDetail,
        anyOf: const [
          AppPermissions.visitsRead,
          AppPermissions.visitsManage,
          AppPermissions.jobsManage,
        ],
        showToast: false,
      );
      expect(denied?.name, AppRoutes.staffHome);
    });

    test('visit detail allows with visitsRead', () async {
      await _putStaffToken(permissions: [AppPermissions.visitsRead]);
      expect(
        redirectMissingPermission(
          route: AppRoutes.staffVisitDetail,
          anyOf: const [
            AppPermissions.visitsRead,
            AppPermissions.visitsManage,
            AppPermissions.jobsManage,
          ],
          showToast: false,
        ),
        isNull,
      );
    });
  });

  group('Phase 4 URL hydrate stubs', () {
    testWidgets('visit and shift detail keep ?id=', (tester) async {
      final router = GoRouter(
        initialLocation: AppRoutes.staffVisits,
        routes: [
          GoRoute(
            path: AppRoutes.staffVisits,
            builder: (_, __) => const Text('board'),
          ),
          GoRoute(
            path: AppRoutes.staffVisitDetail,
            builder: (context, state) {
              Get.parameters
                ..clear()
                ..addAll(state.uri.queryParameters);
              return Text('visit:${state.uri.queryParameters['id']}');
            },
          ),
          GoRoute(
            path: AppRoutes.staffShiftDetail,
            builder: (context, state) {
              Get.parameters
                ..clear()
                ..addAll(state.uri.queryParameters);
              return Text('shift:${state.uri.queryParameters['id']}');
            },
            routes: [
              GoRoute(
                path: 'edit-group',
                builder: (context, state) {
                  Get.parameters
                    ..clear()
                    ..addAll(state.uri.queryParameters);
                  return Text('edit:${state.uri.queryParameters['id']}');
                },
              ),
            ],
          ),
        ],
      );
      AppNavigator.bindWebRouter(router);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      AppNavigator.push(
        AppNavigator.location(AppRoutes.staffVisitDetail, query: {'id': 'v1'}),
      );
      await tester.pumpAndSettle();
      expect(find.text('visit:v1'), findsOneWidget);
      expect(routeParam('id'), 'v1');

      AppNavigator.go(
        AppNavigator.location(AppRoutes.staffShiftDetail, query: {'id': 's9'}),
      );
      await tester.pumpAndSettle();
      expect(find.text('shift:s9'), findsOneWidget);
      expect(routeParam('id'), 's9');
    });

    testWidgets('group edit-group restores from initialLocation ?id=', (
      tester,
    ) async {
      final rootKey = GlobalKey<NavigatorState>();
      final router = GoRouter(
        navigatorKey: rootKey,
        initialLocation: '${AppRoutes.staffGroupShiftEdit}?id=s42',
        routes: [
          GoRoute(
            path: AppRoutes.staffShiftDetail,
            builder: (_, __) => const Text('shift'),
            routes: [
              GoRoute(
                path: 'edit-group',
                parentNavigatorKey: rootKey,
                builder: (context, state) {
                  Get.parameters
                    ..clear()
                    ..addAll(state.uri.queryParameters);
                  return Text('edit:${state.uri.queryParameters['id']}');
                },
              ),
            ],
          ),
        ],
      );
      AppNavigator.bindWebRouter(router);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('edit:s42'), findsOneWidget);
      expect(routeParam('id'), 's42');
      expect(
        locationPath(AppNavigator.currentLocation),
        AppRoutes.staffGroupShiftEdit,
      );
    });

    testWidgets('AppNavigator.backOrToParent returns to roster', (tester) async {
      final router = GoRouter(
        initialLocation: '${AppRoutes.staffVisitDetail}?id=v2',
        routes: [
          GoRoute(
            path: AppRoutes.staffVisits,
            builder: (_, __) => const Text('roster'),
          ),
          GoRoute(
            path: AppRoutes.staffVisitDetail,
            builder: (_, __) => const Text('detail'),
          ),
        ],
      );
      AppNavigator.bindWebRouter(router);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('detail'), findsOneWidget);

      AppNavigator.backOrToParent(AppRoutes.staffVisits);
      await tester.pumpAndSettle();
      expect(find.text('roster'), findsOneWidget);
    });
  });
}
