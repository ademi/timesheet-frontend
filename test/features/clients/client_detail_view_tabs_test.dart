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

  testWidgets('shows subject tabs and Overview first', (tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: ClientDetailView()));

    expect(find.byKey(const ValueKey('client-detail-tab-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('client-detail-tab-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('client-detail-tab-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('client-detail-tab-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('client-detail-tab-4')), findsOneWidget);
    expect(find.text('Overview'), findsWidgets);
    expect(find.byType(FormStickyActions), findsNothing);
    expect(find.text('Date of birth'), findsOneWidget);
    expect(
      find.text(
        'Select a type to show optional profile requirements and documents.',
      ),
      findsNothing,
    );
    expect(find.text('No locations yet.'), findsNothing);
  });

  testWidgets('Locations tab shows only locations content', (tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: ClientDetailView()));

    await tester.tap(find.byKey(const ValueKey('client-detail-tab-2')));
    await tester.pump();

    expect(find.text('No locations yet.'), findsOneWidget);
    expect(find.text('Date of birth'), findsNothing);
    expect(find.text('No contacts yet.'), findsNothing);
  });

  testWidgets('Contacts and Support tabs isolate their sections', (
    tester,
  ) async {
    await tester.pumpWidget(const GetMaterialApp(home: ClientDetailView()));

    await tester.tap(find.byKey(const ValueKey('client-detail-tab-3')));
    await tester.pump();
    expect(find.text('No contacts yet.'), findsOneWidget);
    expect(find.text('No locations yet.'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('client-detail-tab-1')));
    await tester.pump();
    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('Past'), findsOneWidget);
    expect(find.text('No contacts yet.'), findsNothing);
  });

  testWidgets('Details tab lifts FormStickyActions out of the profile scroll', (
    tester,
  ) async {
    await tester.pumpWidget(const GetMaterialApp(home: ClientDetailView()));

    await tester.tap(find.byKey(const ValueKey('client-detail-tab-4')));
    await tester.pump();

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
  });

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
