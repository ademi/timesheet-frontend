import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/clients/data/models/client_models.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/shared/models/profile_photo_models.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';
import 'package:rostiq/features/rostering/data/composer_facade.dart';
import 'package:rostiq/features/rostering/data/composer_models.dart';
import 'package:rostiq/features/rostering/domain/composer_steps.dart';
import 'package:rostiq/features/rostering/domain/occurrence_draft.dart';
import 'package:rostiq/features/rostering/domain/roster_composer_args.dart';
import 'package:rostiq/features/rostering/presentation/composer/roster_composer_controller.dart';
import 'package:rostiq/features/rostering/presentation/composer/roster_composer_view.dart';
import 'package:rostiq/features/shifts/data/repositories/shifts_repository.dart';

class _MockShiftsRepository extends Mock implements ShiftsRepository {}

class _MockJobsRepository extends Mock implements JobsRepository {}

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _MockSessionService extends Mock implements SessionService {}

ClientOut _client(String id) => ClientOut(
  id: id,
  tenantId: 't1',
  fullName: 'Sam',
  status: 'active',
  metadata: const {},
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

void main() {
  late RosterComposerController controller;
  late _MockShiftsRepository shifts;
  late _MockJobsRepository jobs;
  late _MockClientsRepository clients;
  late _MockSessionService session;

  setUp(() {
    Get.reset();
    Get.testMode = true;
    shifts = _MockShiftsRepository();
    jobs = _MockJobsRepository();
    clients = _MockClientsRepository();
    session = _MockSessionService();

    when(() => session.hasPermission(any())).thenReturn(true);
    when(() => session.tenantTimezone).thenReturn(RxnString());
    when(() => clients.listClients()).thenAnswer((_) async => [_client('c1')]);
    when(() => clients.getClient(any())).thenAnswer((_) async => _client('c1'));
    when(
      () => clients.getClientProfilePhoto(any()),
    ).thenAnswer((_) async => const ProfilePhotoOut());
    when(
      () => shifts.fetchPlaceOptions(participantIds: any(named: 'participantIds')),
    ).thenAnswer((_) async => const PlaceOptionsOut());
    when(
      () => jobs.listFormTemplates(tenantLevel: any(named: 'tenantLevel')),
    ).thenAnswer((_) async => []);
    when(
      () => shifts.fetchAssignContext(
        from: any(named: 'from'),
        to: any(named: 'to'),
        clientId: any(named: 'clientId'),
      ),
    ).thenAnswer((_) async => const AssignContextOut());

    controller = RosterComposerController(
      facade: ComposerFacade(shifts: shifts, jobs: jobs),
      clientsRepository: clients,
      session: session,
      args: const RosterComposerArgs(preset: ComposerPreset.oneSession),
    );
    Get.put(controller);
  });

  tearDown(Get.reset);

  testWidgets('stepped wizard shows Clients first; Next/Back; Publish on last', (
    tester,
  ) async {
    await controller.retryHydrate();
    await tester.pumpWidget(const GetMaterialApp(home: RosterComposerView()));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byKey(const Key('composer-preset')), findsOneWidget);
    expect(find.byKey(const Key('composer-step-label')), findsOneWidget);
    expect(find.text('1. Clients'), findsOneWidget);
    expect(find.byKey(const Key('composer-next')), findsOneWidget);
    expect(find.byKey(const Key('composer-save-draft')), findsNothing);
    expect(find.byKey(const Key('composer-publish')), findsNothing);

    // Gate: cannot advance without a client.
    await tester.tap(find.byKey(const Key('composer-next')));
    await tester.pumpAndSettle();
    expect(controller.currentStep.value, ComposerStep.clients);

    controller.addParticipant(_client('c1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('composer-next')));
    await tester.pumpAndSettle();
    expect(controller.currentStep.value, ComposerStep.when);
    expect(find.text('2. When'), findsOneWidget);

    // Prefill gates, then jump to last step for footer assertions.
    controller.draft.value = controller.draft.value.copyWith(
      scheduledStart: DateTime(2026, 10, 6, 9),
      scheduledEnd: DateTime(2026, 10, 6, 12),
      place: const DraftPlace.branch('b1'),
    );
    controller.currentStep.value = ComposerStep.workers;
    await tester.pumpAndSettle();
    // Flush place-options / assign-context debouncers.
    await tester.pump(const Duration(milliseconds: 350));

    expect(controller.currentStep.value, ComposerStep.workers);
    expect(find.byKey(const Key('composer-save-draft')), findsOneWidget);
    expect(find.byKey(const Key('composer-publish')), findsOneWidget);
    expect(find.byKey(const Key('composer-next')), findsNothing);
  });

  testWidgets('one session hides allocation UI on Clients step', (tester) async {
    await controller.retryHydrate();
    await tester.pumpWidget(const GetMaterialApp(home: RosterComposerView()));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byKey(const Key('composer-allocation')), findsNothing);

    controller.setPreset(ComposerPreset.group);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byKey(const Key('composer-allocation')), findsOneWidget);
    expect(find.byKey(const Key('composer-worker-count')), findsOneWidget);
  });
}
