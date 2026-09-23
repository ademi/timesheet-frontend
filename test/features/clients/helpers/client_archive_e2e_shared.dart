/// Shared staff client-archive E2E body (Task 8 / eng-review D16=C).
///
/// Used by:
/// - `test/features/clients/client_archive_e2e_test.dart` (VM / CI)
/// - `integration_test/client_archive_e2e_test.dart` (device when desktop deps present)
///
/// Lives under `helpers/` so it is not matched by `client_archive_*.dart` globs.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/clients/controllers/clients_controller.dart';
import 'package:rostiq/features/clients/data/models/client_models.dart';
import 'package:rostiq/features/clients/data/models/client_profile_models.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/clients/views/client_detail_view.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';
import 'package:rostiq/shared/models/profile_photo_models.dart';

class MockClientsRepositoryForArchiveE2e extends Mock
    implements ClientsRepository {}

class MockJobsRepositoryForArchiveE2e extends Mock implements JobsRepository {}

class MockSessionServiceForArchiveE2e extends Mock implements SessionService {}

final _now = DateTime.utc(2026, 9, 23, 10);

final activeClientForArchiveE2e = ClientOut(
  id: 'client-archive-1',
  tenantId: 'tenant-1',
  fullName: 'Archive Journey Client',
  status: 'active',
  email: 'archive@example.com',
  phone: '+61400000999',
  metadata: const {},
  createdAt: _now,
  updatedAt: _now,
);

final archivedClientForArchiveE2e = ClientOut(
  id: 'client-archive-1',
  tenantId: 'tenant-1',
  fullName: 'Archive Journey Client',
  status: 'archived',
  email: 'archive@example.com',
  phone: '+61400000999',
  metadata: const {},
  createdAt: _now,
  updatedAt: _now,
);

/// Registers GetX + mocks and declares the staff archive journey test.
void declareClientArchiveStaffE2e() {
  late MockClientsRepositoryForArchiveE2e clients;
  late MockJobsRepositoryForArchiveE2e jobs;
  late MockSessionServiceForArchiveE2e session;
  late ClientsController controller;
  var deleteClientCalls = 0;
  var restoreClientCalls = 0;
  String? lastRestoreTarget;

  void stubReadPaths(ClientOut client) {
    when(() => session.hasPermission(any())).thenReturn(true);
    when(() => clients.listClients()).thenAnswer((_) async => [client]);
    when(() => clients.getClient(any())).thenAnswer((_) async => client);
    when(
      () => clients.getClientProfilePhoto(any()),
    ).thenAnswer((_) async => const ProfilePhotoOut(hasPhoto: false));
    when(() => clients.listClientTypes()).thenAnswer((_) async => []);
    when(() => clients.listSupportPlans(any())).thenAnswer((_) async => []);
    when(
      () => clients.getClientProfile(any()),
    ).thenAnswer((_) async => const ClientProfileBundle(facts: []));
    when(() => clients.listSites(any())).thenAnswer((_) async => []);
    when(() => clients.listContacts(any())).thenAnswer((_) async => []);
    when(() => clients.listStrengthsNeeds(any())).thenAnswer((_) async => []);
  }

  setUp(() {
    Get.reset();
    Get.testMode = true;
    clients = MockClientsRepositoryForArchiveE2e();
    jobs = MockJobsRepositoryForArchiveE2e();
    session = MockSessionServiceForArchiveE2e();
    deleteClientCalls = 0;
    restoreClientCalls = 0;
    lastRestoreTarget = null;
    stubReadPaths(activeClientForArchiveE2e);
    when(() => clients.deleteClient(any())).thenAnswer((_) async {
      deleteClientCalls++;
    });
    when(
      () => clients.restoreClient(any(), targetStatus: any(named: 'targetStatus')),
    ).thenAnswer((invocation) async {
      restoreClientCalls++;
      lastRestoreTarget =
          invocation.namedArguments[#targetStatus] as String? ?? 'active';
      return activeClientForArchiveE2e;
    });
    controller = ClientsController(
      repository: clients,
      session: session,
      jobsRepository: jobs,
    );
    controller.selected.value = activeClientForArchiveE2e;
    controller.hydrateOverviewDrafts();
    Get.put(controller);
  });

  tearDown(() {
    Get.closeAllSnackbars();
    Get.reset();
  });

  testWidgets('staff archives client and detail becomes read-only', (
    tester,
  ) async {
    await tester.pumpWidget(const GetMaterialApp(home: ClientDetailView()));
    await tester.pump();

    expect(find.byTooltip('Archive'), findsOneWidget);
    await tester.tap(find.byTooltip('Archive'));
    await tester.pump(); // open dialog

    expect(
      find.textContaining('kept for legal and audit requirements'),
      findsOneWidget,
    );

    // Confirm button in dialog (not the AppBar tooltip).
    await tester.tap(find.widgetWithText(TextButton, 'Archive'));
    await tester.pump(); // start delete
    await tester.pump(); // finish async delete + load

    expect(deleteClientCalls, 1);
    verify(() => clients.deleteClient(activeClientForArchiveE2e.id)).called(1);

    // Re-pump detail with archived status (read-only chrome).
    stubReadPaths(archivedClientForArchiveE2e);
    controller.selected.value = archivedClientForArchiveE2e;
    await tester.pumpWidget(const GetMaterialApp(home: ClientDetailView()));
    await tester.pump();

    expect(find.byTooltip('Edit'), findsNothing);
    expect(find.byTooltip('Archive'), findsNothing);
    expect(find.byTooltip('Restore'), findsOneWidget);
    expect(find.textContaining('Archived'), findsWidgets);
  });

  testWidgets('staff restores archived client to active', (tester) async {
    stubReadPaths(archivedClientForArchiveE2e);
    when(() => clients.getClient(any())).thenAnswer((_) async {
      return activeClientForArchiveE2e;
    });
    when(() => clients.listClients()).thenAnswer(
      (_) async => [activeClientForArchiveE2e],
    );
    controller.selected.value = archivedClientForArchiveE2e;
    controller.hydrateOverviewDrafts();

    await tester.pumpWidget(const GetMaterialApp(home: ClientDetailView()));
    await tester.pump();

    expect(find.byTooltip('Restore'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Restore'));
    await tester.pump(); // open dialog

    expect(find.text('Restore client?'), findsOneWidget);
    expect(
      find.textContaining('not automatically reopened'),
      findsOneWidget,
    );
    expect(find.textContaining('stay revoked'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Inactive'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Restore').last);
    await tester.pump(); // start restore
    await tester.pump(); // finish async restore + refresh

    expect(restoreClientCalls, 1);
    expect(lastRestoreTarget, 'active');
    verify(
      () => clients.restoreClient(
        archivedClientForArchiveE2e.id,
        targetStatus: 'active',
      ),
    ).called(1);
    expect(controller.selected.value?.status, 'active');
    expect(find.byTooltip('Archive'), findsOneWidget);
    expect(find.byTooltip('Restore'), findsNothing);
  });
}
