import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/router/go_router_params.dart';
import 'package:rostiq/app/routes/app_navigator.dart';
import 'package:rostiq/app/routes/app_routes.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/sil/bindings/sil_bindings.dart';
import 'package:rostiq/features/sil/controllers/sil_houses_controller.dart';
import 'package:rostiq/features/sil/data/models/sil_models.dart';
import 'package:rostiq/features/sil/data/repositories/sil_repository.dart';
import 'package:rostiq/features/sil/views/sil_houses_views.dart';

class MockSilRepository extends Mock implements SilRepository {}

class MockClientsRepository extends Mock implements ClientsRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSilRepository sil;
  late MockClientsRepository clients;

  setUp(() {
    Get.testMode = true;
    Get.reset();
    sil = MockSilRepository();
    clients = MockClientsRepository();
    Get.put<SilRepository>(sil);
    Get.put<ClientsRepository>(clients);
    when(() => clients.listClients()).thenAnswer((_) async => []);
  });

  tearDown(() {
    AppNavigator.debugUnbindWebRouter();
    Get.reset();
  });

  testWidgets('detail push registers SilHouseDetailController', (tester) async {
    const house = SilHouseOut(
      id: 'house-1',
      tenantId: 't1',
      name: 'Test House',
    );
    const bundle = SilHouseBundleOut(
      house: house,
      members: [],
      rocBlocks: [],
      presentOccupancy: 0,
    );
    when(() => sil.getHouse('house-1')).thenAnswer((_) async => bundle);
    when(() => sil.getOverlay('house-1')).thenThrow(Exception('none'));
    when(() => sil.listCompatRules('house-1')).thenAnswer((_) async => []);

    final router = GoRouter(
      initialLocation: AppRoutes.staffSilHouses,
      routes: [
        ShellRoute(
          builder: (context, state, child) => Scaffold(body: child),
          routes: [
            GoRoute(
              path: AppRoutes.staffSilHouses,
              builder: (context, state) {
                syncGetxFromGoRouterState(state);
                return const Text('list');
              },
            ),
            GoRoute(
              path: AppRoutes.staffSilHouseDetail,
              builder: (context, state) {
                syncGetxFromGoRouterState(state);
                SilHouseDetailBinding().dependencies();
                return const SilHouseDetailView();
              },
            ),
          ],
        ),
      ],
    );
    AppNavigator.bindWebRouter(router);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();

    // Don't await push — it completes only when the route is popped.
    // ignore: unawaited_futures
    AppNavigator.push(
      AppNavigator.location(
        AppRoutes.staffSilHouseDetail,
        query: {'id': 'house-1'},
      ),
      extra: {'house_id': 'house-1'},
    );
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(Get.isRegistered<SilHouseDetailController>(), isTrue);
    expect(Get.find<SilHouseDetailController>().houseId, 'house-1');
    expect(find.byType(SilHouseDetailView), findsOneWidget);
  });

  testWidgets('detail push without query still uses extra house_id', (
    tester,
  ) async {
    const house = SilHouseOut(
      id: 'house-2',
      tenantId: 't1',
      name: 'Extra House',
    );
    const bundle = SilHouseBundleOut(
      house: house,
      members: [],
      rocBlocks: [],
      presentOccupancy: 0,
    );
    when(() => sil.getHouse('house-2')).thenAnswer((_) async => bundle);
    when(() => sil.getOverlay('house-2')).thenThrow(Exception('none'));
    when(() => sil.listCompatRules('house-2')).thenAnswer((_) async => []);

    final router = GoRouter(
      initialLocation: AppRoutes.staffSilHouses,
      routes: [
        ShellRoute(
          builder: (context, state, child) => Scaffold(body: child),
          routes: [
            GoRoute(
              path: AppRoutes.staffSilHouses,
              builder: (context, state) {
                syncGetxFromGoRouterState(state);
                return const Text('list');
              },
            ),
            GoRoute(
              path: AppRoutes.staffSilHouseDetail,
              builder: (context, state) {
                syncGetxFromGoRouterState(state);
                SilHouseDetailBinding().dependencies();
                return const SilHouseDetailView();
              },
            ),
          ],
        ),
      ],
    );
    AppNavigator.bindWebRouter(router);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();

    // Push path without query; extra must hydrate the binding.
    // ignore: unawaited_futures
    AppNavigator.push(
      AppRoutes.staffSilHouseDetail,
      extra: {'house_id': 'house-2'},
    );
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(Get.isRegistered<SilHouseDetailController>(), isTrue);
    expect(Get.find<SilHouseDetailController>().houseId, 'house-2');
    expect(find.byType(SilHouseDetailView), findsOneWidget);
  });
}
