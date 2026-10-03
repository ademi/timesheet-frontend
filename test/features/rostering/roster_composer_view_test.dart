import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/clients/data/models/client_models.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';
import 'package:rostiq/features/rostering/data/composer_facade.dart';
import 'package:rostiq/features/rostering/data/composer_models.dart';
import 'package:rostiq/features/rostering/domain/occurrence_draft.dart';
import 'package:rostiq/features/rostering/domain/roster_composer_args.dart';
import 'package:rostiq/features/rostering/presentation/composer/roster_composer_controller.dart';
import 'package:rostiq/features/rostering/presentation/composer/roster_composer_view.dart';
import 'package:rostiq/features/shifts/data/repositories/shifts_repository.dart';

class _MockShiftsRepository extends Mock implements ShiftsRepository {}

class _MockJobsRepository extends Mock implements JobsRepository {}

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _MockSessionService extends Mock implements SessionService {}

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
    when(() => clients.listClients()).thenAnswer((_) async => <ClientOut>[]);
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

  testWidgets('preset control and sticky Save draft / Publish', (tester) async {
    await controller.retryHydrate();
    await tester.pumpWidget(const GetMaterialApp(home: RosterComposerView()));
    await tester.pumpAndSettle();
    // Flush place-options debounce (200ms).
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byKey(const Key('composer-preset')), findsOneWidget);
    expect(find.text('One session'), findsWidgets);
    expect(find.text('Group'), findsWidgets);
    expect(find.byKey(const Key('composer-save-draft')), findsOneWidget);
    expect(find.text('Save draft'), findsOneWidget);
    expect(find.byKey(const Key('composer-publish')), findsOneWidget);
  });

  testWidgets('one session hides allocation UI', (tester) async {
    await controller.retryHydrate();
    await tester.pumpWidget(const GetMaterialApp(home: RosterComposerView()));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byKey(const Key('composer-allocation')), findsNothing);

    controller.setPreset(ComposerPreset.group);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byKey(const Key('composer-allocation')), findsOneWidget);
  });
}
