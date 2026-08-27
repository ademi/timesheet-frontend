import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/routes/app_routes.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/clients/controllers/clients_controller.dart';
import 'package:rostiq/features/clients/controllers/support_plan_controller.dart';
import 'package:rostiq/features/clients/data/models/client_models.dart';
import 'package:rostiq/features/clients/data/models/client_profile_models.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/clients/views/client_detail_view.dart';
import 'package:rostiq/features/clients/views/support_plan_view.dart';
import 'package:rostiq/features/clients/widgets/support_plan_form_body.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';
import 'package:rostiq/shared/models/profile_photo_models.dart';
import 'package:rostiq/shared/widgets/form_sticky_actions.dart';

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _MockJobsRepository extends Mock implements JobsRepository {}

class _MockSessionService extends Mock implements SessionService {}

final _now = DateTime.utc(2026, 8, 27, 9);

final _client = ClientOut(
  id: 'client-1',
  tenantId: 'tenant-1',
  fullName: 'Demo Payments Client',
  status: 'active',
  email: 'payments.client@demotenant.example',
  phone: '+61400000100',
  metadata: const {},
  createdAt: _now,
  updatedAt: _now,
);

final _client2 = ClientOut(
  id: 'client-2',
  tenantId: 'tenant-1',
  fullName: 'Second Client',
  status: 'active',
  metadata: const {},
  createdAt: _now,
  updatedAt: _now,
);

Future<void> _openTab(WidgetTester tester, int index) async {
  final key = find.byKey(ValueKey('client-detail-tab-$index'));
  await tester.ensureVisible(key);
  await tester.tap(key);
  await tester.pump();
  await tester.pump();
}

void main() {
  late _MockClientsRepository clients;
  late _MockJobsRepository jobs;
  late _MockSessionService session;
  late ClientsController controller;

  setUp(() {
    Get.testMode = true;
    Get.reset();
    clients = _MockClientsRepository();
    jobs = _MockJobsRepository();
    session = _MockSessionService();
    when(() => session.hasPermission(any())).thenReturn(true);
    when(() => clients.listClients()).thenAnswer((_) async => [_client]);
    when(
      () => clients.getClientProfilePhoto(any()),
    ).thenAnswer((_) async => const ProfilePhotoOut(hasPhoto: false));
    when(() => clients.listClientTypes()).thenAnswer((_) async => []);
    when(() => clients.listSupportPlans(any())).thenAnswer((_) async => []);
    when(() => clients.listSites(any())).thenAnswer((_) async => []);
    when(() => clients.listContacts(any())).thenAnswer((_) async => []);
    when(
      () => clients.getClientProfile(any()),
    ).thenAnswer((_) async => const ClientProfileBundle(facts: []));
    when(() => clients.getClient(_client.id)).thenAnswer((_) async => _client);
    when(
      () => clients.getClient(_client2.id),
    ).thenAnswer((_) async => _client2);
    controller = ClientsController(
      repository: clients,
      session: session,
      jobsRepository: jobs,
    );
    controller.selected.value = _client;
    controller.hydrateOverviewDrafts();
    Get.put(controller);
  });

  tearDown(() {
    Get.closeAllSnackbars();
    Get.reset();
  });

  testWidgets(
    'Care plan shows plan fields without pushing support-plan route',
    (tester) async {
      await tester.pumpWidget(const GetMaterialApp(home: ClientDetailView()));
      await _openTab(tester, ClientsController.tabCarePlan);

      expect(find.byType(ClientDetailView), findsOneWidget);
      expect(find.byType(SupportPlanFormBody), findsOneWidget);
      expect(find.text('Primary disability'), findsOneWidget);
      expect(find.text('Save draft'), findsOneWidget);
      expect(find.text('Activate'), findsOneWidget);
      expect(find.byType(SupportPlanView), findsNothing);
      expect(Get.currentRoute, isNot(AppRoutes.staffClientSupportPlan));
      expect(find.text('Start ongoing support'), findsNothing);
      expect(find.text('Book one session'), findsNothing);
    },
  );

  testWidgets('Care plan Cancel does not pop ClientDetailView', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/',
        getPages: [
          GetPage(
            name: '/',
            page: () => const Scaffold(body: Text('clients-list')),
          ),
          GetPage(
            name: AppRoutes.staffClientDetail,
            page: () => const ClientDetailView(),
          ),
        ],
      ),
    );
    Get.toNamed(AppRoutes.staffClientDetail);
    await tester.pump();
    await tester.pump();

    await _openTab(tester, ClientsController.tabCarePlan);
    expect(find.byType(ClientDetailView), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(ClientDetailView), findsOneWidget);
    expect(find.text('Demo Payments Client'), findsWidgets);
    expect(Get.currentRoute, AppRoutes.staffClientDetail);
  });

  testWidgets('Care plan sticky Save draft/Activate sit outside the scroll', (
    tester,
  ) async {
    await tester.pumpWidget(const GetMaterialApp(home: ClientDetailView()));
    await _openTab(tester, ClientsController.tabCarePlan);

    expect(find.byType(FormStickyActions), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ListView),
        matching: find.byType(FormStickyActions),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(ListView),
        matching: find.text('Save draft'),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'staffClientSupportPlan route still builds with Get.back Cancel',
    (tester) async {
      Get.put(SupportPlanController(repository: clients, clientId: 'client-1'));

      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: '/',
          getPages: [
            GetPage(name: '/', page: () => const Scaffold(body: Text('home'))),
            GetPage(
              name: AppRoutes.staffClientSupportPlan,
              page: () => const SupportPlanView(),
            ),
          ],
        ),
      );
      Get.toNamed(AppRoutes.staffClientSupportPlan);
      await tester.pump();
      await tester.pump();

      expect(find.byType(SupportPlanView), findsOneWidget);
      expect(find.text('Support plan'), findsOneWidget);
      expect(find.byType(SupportPlanFormBody), findsOneWidget);
      expect(find.text('Primary disability'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump();

      expect(find.text('home'), findsOneWidget);
      expect(find.byType(SupportPlanView), findsNothing);
    },
  );

  test('ensureCarePlanController puts and replaces per client id', () {
    controller.ensureCarePlanController();
    expect(Get.isRegistered<SupportPlanController>(), isTrue);
    final first = Get.find<SupportPlanController>();
    expect(first.clientId, 'client-1');

    controller.ensureCarePlanController();
    expect(identical(Get.find<SupportPlanController>(), first), isTrue);

    controller.selected.value = _client2;
    controller.ensureCarePlanController();
    final second = Get.find<SupportPlanController>();
    expect(second.clientId, 'client-2');
    expect(identical(first, second), isFalse);
  });

  test(
    'openDetailById deletes care plan controller on client change',
    () async {
      controller.tabIndex.value = ClientsController.tabCarePlan;
      controller.ensureCarePlanController();
      expect(Get.find<SupportPlanController>().clientId, 'client-1');

      when(() => jobs.listJobs()).thenAnswer((_) async => []);
      await controller.openDetailById(_client2.id);

      expect(Get.isRegistered<SupportPlanController>(), isTrue);
      expect(Get.find<SupportPlanController>().clientId, 'client-2');
    },
  );
}
