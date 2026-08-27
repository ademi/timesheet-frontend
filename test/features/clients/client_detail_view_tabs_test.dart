import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/clients/controllers/clients_controller.dart';
import 'package:rostiq/features/clients/data/models/client_models.dart';
import 'package:rostiq/shared/models/profile_photo_models.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/clients/views/client_detail_view.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';
import 'package:rostiq/shared/widgets/form_sticky_actions.dart';
import 'package:rostiq/shared/widgets/subject_tab_bar.dart';

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _MockJobsRepository extends Mock implements JobsRepository {}

class _MockSessionService extends Mock implements SessionService {}

final _now = DateTime.utc(2026, 8, 18, 9);

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

Future<void> _openTab(WidgetTester tester, int index) async {
  final key = find.byKey(ValueKey('client-detail-tab-$index'));
  await tester.ensureVisible(key);
  await tester.tap(key);
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
    controller = ClientsController(
      repository: clients,
      session: session,
      jobsRepository: jobs,
    );
    controller.selected.value = _client;
    Get.put(controller);
  });

  tearDown(Get.reset);

  test('Option B tab constants and aliases share new ints', () {
    expect(ClientsController.tabOverview, 0);
    expect(ClientsController.tabCarePlan, 1);
    expect(ClientsController.tabProfile, 2);
    expect(ClientsController.tabPeople, 3);
    expect(ClientsController.tabPlaces, 4);
    expect(ClientsController.tabVisits, 5);
    expect(ClientsController.tabSupport, ClientsController.tabCarePlan);
    expect(ClientsController.tabDetails, ClientsController.tabProfile);
    expect(ClientsController.tabContacts, ClientsController.tabPeople);
    expect(ClientsController.tabLocations, ClientsController.tabPlaces);
    expect(ClientsController.tabSites, ClientsController.tabPlaces);
    expect(ClientsController.tabDetails, isNot(4));
    expect(ClientsController.tabLocations, isNot(2));
    expect(ClientsController.tabSites, isNot(2));
  });

  testWidgets('shows six Option B tabs with Overview first', (tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: ClientDetailView()));

    for (var i = 0; i < 6; i++) {
      expect(find.byKey(ValueKey('client-detail-tab-$i')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('client-detail-tab-6')), findsNothing);

    final bar = tester.widget<SubjectTabBar>(find.byType(SubjectTabBar));
    expect(bar.labels, [
      'Overview',
      'Care plan',
      'Profile & docs',
      'People',
      'Places',
      'Visits',
    ]);
    expect(bar.labels[ClientsController.tabCarePlan], 'Care plan');
    expect(bar.labels[ClientsController.tabVisits], 'Visits');

    expect(find.byType(FormStickyActions), findsNothing);
    expect(find.text('Date of birth'), findsOneWidget);
    expect(
      find.text(
        'Select a type to show optional profile requirements and documents.',
      ),
      findsNothing,
    );
    expect(find.text('No locations yet.'), findsNothing);
    expect(find.text('Upcoming'), findsNothing);
  });

  testWidgets('Places empty state is on tab 4, not Profile', (tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: ClientDetailView()));

    await _openTab(tester, ClientsController.tabProfile);
    expect(find.text('No locations yet.'), findsNothing);
    expect(find.byType(FormStickyActions), findsOneWidget);

    await _openTab(tester, ClientsController.tabPlaces);
    expect(find.text('No locations yet.'), findsOneWidget);
    expect(find.text('Date of birth'), findsNothing);
    expect(find.text('No contacts yet.'), findsNothing);
    expect(find.byType(FormStickyActions), findsNothing);
  });

  testWidgets('People and Care plan tabs isolate their sections', (
    tester,
  ) async {
    await tester.pumpWidget(const GetMaterialApp(home: ClientDetailView()));

    await _openTab(tester, ClientsController.tabPeople);
    expect(find.text('No contacts yet.'), findsOneWidget);
    expect(find.text('No locations yet.'), findsNothing);
    expect(find.text('Upcoming'), findsNothing);

    await _openTab(tester, ClientsController.tabCarePlan);
    expect(find.text('Support'), findsOneWidget);
    expect(find.text('Upcoming'), findsNothing);
    expect(find.text('Past'), findsNothing);
    expect(find.text('No contacts yet.'), findsNothing);
  });

  testWidgets('Visits tab is index 5 and shows visit lists', (tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: ClientDetailView()));

    await _openTab(tester, ClientsController.tabVisits);
    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('Past'), findsOneWidget);
    expect(find.text('No contacts yet.'), findsNothing);
    expect(find.byType(FormStickyActions), findsNothing);
  });

  testWidgets(
    'Profile tab lifts FormStickyActions out of the profile scroll',
    (tester) async {
      await tester.pumpWidget(const GetMaterialApp(home: ClientDetailView()));

      await _openTab(tester, ClientsController.tabProfile);

      controller.errorMessage.value = 'NDIS number is required.';
      await tester.pump();

      expect(find.byType(FormStickyActions), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save type & profile'), findsOneWidget);
      expect(find.text('NDIS number is required.'), findsOneWidget);
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
          matching: find.text('Save type & profile'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.text('NDIS number is required.'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets('incomplete client shows amber banner and Continue onboarding', (
    tester,
  ) async {
    final incomplete = ClientOut(
      id: 'client-incomplete',
      tenantId: 'tenant-1',
      fullName: 'Incomplete Client',
      status: 'active',
      email: 'incomplete@example.com',
      metadata: const {'onboarding_incomplete': true},
      createdAt: _now,
      updatedAt: _now,
    );
    controller.selected.value = incomplete;

    await tester.pumpWidget(const GetMaterialApp(home: ClientDetailView()));
    await tester.pump();

    expect(find.text('Continue onboarding'), findsOneWidget);
    expect(find.text('Onboarding incomplete'), findsOneWidget);
  });
}
