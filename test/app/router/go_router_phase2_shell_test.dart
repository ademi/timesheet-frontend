import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/constants/app_permissions.dart';
import 'package:rostiq/app/router/go_router_redirect.dart';
import 'package:rostiq/app/router/shell_go_routes.dart';
import 'package:rostiq/app/routes/app_navigator.dart';
import 'package:rostiq/app/routes/app_routes.dart';
import 'package:rostiq/app/routes/middlewares/auth_route_utils.dart';
import 'package:rostiq/core/services/token_storage.dart';
import 'package:rostiq/features/shell/staff_shell.dart';

String _fakeJwt(Map<String, dynamic> payload) {
  final header = base64Url.encode(
    utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})),
  );
  final body = base64Url.encode(utf8.encode(jsonEncode(payload)));
  return '$header.$body.signature';
}

Future<TokenStorage> _putStorage(Map<String, dynamic> claims) async {
  final storage = TokenStorage();
  await storage.persistTokens(
    accessToken: _fakeJwt({
      'exp':
          DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
          1000,
      ...claims,
    }),
    refreshToken: 'refresh',
  );
  Get.put<TokenStorage>(storage);
  return storage;
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

  group('Phase 2 shell redirects', () {
    test('contractor cannot open staff shell tab', () async {
      await _putStorage({'actor_type': 'contractor'});

      expect(
        appGoRouterRedirect(
          _FakeContext(),
          _FakeGoRouterState(AppRoutes.staffClients),
        ),
        AppRoutes.wrongActor,
      );
    });

    test('redirectMissingPermission denies via JWT claims', () async {
      // No SessionService — claims-only path.
      await _putStorage({
        'actor_type': 'tenant_member',
        'permissions': [AppPermissions.authSession],
      });

      final denied = redirectMissingPermission(
        route: AppRoutes.staffClients,
        anyOf: const [AppPermissions.clientsRead],
        showToast: false,
      );
      expect(denied?.name, AppRoutes.staffHome);
    });

    test('redirectMissingPermission allows via JWT claims', () async {
      await _putStorage({
        'actor_type': 'tenant_member',
        'permissions': [AppPermissions.clientsRead],
      });

      expect(
        redirectMissingPermission(
          route: AppRoutes.staffClients,
          anyOf: const [AppPermissions.clientsRead],
          showToast: false,
        ),
        isNull,
      );
    });
  });

  group('Phase 2 ShellRoute wiring', () {
    test('buildShellGoRoutes registers staff and contractor tabs', () {
      final routes = buildShellGoRoutes();
      expect(routes.length, 2);

      final staff = routes[0] as ShellRoute;
      final contractor = routes[1] as ShellRoute;
      expect(staff.routes.length, 12);
      expect(contractor.routes.length, 6);

      final staffPaths =
          staff.routes.whereType<GoRoute>().map((r) => r.path).toSet();
      expect(staffPaths, contains(AppRoutes.staffHome));
      expect(staffPaths, contains(AppRoutes.staffClients));
      expect(staffPaths, contains(AppRoutes.staffVisits));
      expect(staffPaths, contains(AppRoutes.staffSettings));
      expect(staffPaths, contains(AppRoutes.staffSilHouses));
      expect(staffPaths, contains(AppRoutes.staffSilHouseDetail));
      expect(staffPaths, contains(AppRoutes.staffJobs));

      final contractorPaths =
          contractor.routes.whereType<GoRoute>().map((r) => r.path).toSet();
      expect(contractorPaths, contains(AppRoutes.contractorHome));
      expect(contractorPaths, contains(AppRoutes.contractorVisits));
      expect(contractorPaths, contains(AppRoutes.contractorVisitDetail));
      expect(contractorPaths, contains(AppRoutes.contractorProfile));
    });

    testWidgets('ShellRoute keeps shell chrome across tab go()', (tester) async {
      final router = GoRouter(
        initialLocation: AppRoutes.staffHome,
        routes: [
          ShellRoute(
            builder: (context, state, child) {
              return Scaffold(
                appBar: AppBar(title: const Text('shell-chrome')),
                body: child,
              );
            },
            routes: [
              GoRoute(
                path: AppRoutes.staffHome,
                builder: (_, __) => const Text('home-tab'),
              ),
              GoRoute(
                path: AppRoutes.staffSettings,
                builder: (_, __) => const Text('settings-tab'),
              ),
            ],
          ),
        ],
      );
      AppNavigator.bindWebRouter(router);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('shell-chrome'), findsOneWidget);
      expect(find.text('home-tab'), findsOneWidget);

      AppNavigator.go(AppRoutes.staffSettings);
      await tester.pumpAndSettle();

      expect(find.text('shell-chrome'), findsOneWidget);
      expect(find.text('settings-tab'), findsOneWidget);
      expect(
        locationPath(AppNavigator.currentLocation),
        AppRoutes.staffSettings,
      );
    });

    testWidgets('ShellRoute keeps contractor chrome across tab go()', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: AppRoutes.contractorHome,
        routes: [
          ShellRoute(
            builder: (context, state, child) {
              return Scaffold(
                appBar: AppBar(title: const Text('contractor-chrome')),
                body: child,
              );
            },
            routes: [
              GoRoute(
                path: AppRoutes.contractorHome,
                builder: (_, __) => const Text('c-home'),
              ),
              GoRoute(
                path: AppRoutes.contractorProfile,
                builder: (_, __) => const Text('c-profile'),
              ),
            ],
          ),
        ],
      );
      AppNavigator.bindWebRouter(router);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('contractor-chrome'), findsOneWidget);
      expect(find.text('c-home'), findsOneWidget);

      AppNavigator.go(AppRoutes.contractorProfile);
      await tester.pumpAndSettle();

      expect(find.text('contractor-chrome'), findsOneWidget);
      expect(find.text('c-profile'), findsOneWidget);
    });
  });

  group('StaffShellNav', () {
    test('selectedIndex resolves home and settings paths', () {
      expect(StaffShellNav.selectedIndex(AppRoutes.staffHome), 0);
      expect(
        StaffShellNav.selectedIndex(AppRoutes.staffSettings),
        greaterThan(0),
      );
    });

    testWidgets('navigateTo goes via AppNavigator when router bound', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: AppRoutes.staffHome,
        routes: [
          GoRoute(
            path: AppRoutes.staffHome,
            builder: (_, __) => const SizedBox(),
          ),
          GoRoute(
            path: AppRoutes.staffSettings,
            builder: (_, __) => const SizedBox(),
          ),
        ],
      );
      AppNavigator.bindWebRouter(router);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      StaffShellNav.navigateTo(0);
      await tester.pumpAndSettle();
      expect(locationPath(AppNavigator.currentLocation), AppRoutes.staffHome);
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
