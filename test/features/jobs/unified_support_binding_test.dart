import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/clients/data/models/client_models.dart';
import 'package:rostiq/features/clients/data/models/client_profile_models.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/engagements/data/repositories/engagements_repository.dart';
import 'package:rostiq/features/jobs/controllers/unified_support_controller.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';
import 'package:rostiq/features/jobs/utils/unified_support_args.dart';
import 'package:rostiq/features/shifts/data/repositories/shifts_repository.dart';
import 'package:rostiq/features/visits/data/repositories/visits_repository.dart';

class _MockJobsRepository extends Mock implements JobsRepository {}

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _MockEngagementsRepository extends Mock
    implements EngagementsRepository {}

class _MockShiftsRepository extends Mock implements ShiftsRepository {}

class _MockVisitsRepository extends Mock implements VisitsRepository {}

class _MockSessionService extends Mock implements SessionService {}

ClientOut _client(String id, String name) => ClientOut(
  id: id,
  tenantId: 'tenant-1',
  fullName: name,
  status: 'active',
  metadata: const {},
  createdAt: DateTime.utc(2026, 8, 13),
  updatedAt: DateTime.utc(2026, 8, 13),
);

/// Mirrors [UnifiedSupportBinding]: delete any prior composer, then put a fresh
/// controller with the current route args so the client cannot stick.
UnifiedSupportController _putComposer({
  required JobsRepository jobs,
  required ClientsRepository clients,
  required EngagementsRepository engagements,
  required ShiftsRepository shifts,
  required VisitsRepository visits,
  required SessionService session,
  required UnifiedSupportArgs args,
}) {
  if (Get.isRegistered<UnifiedSupportController>()) {
    Get.delete<UnifiedSupportController>(force: true);
  }
  return Get.put(
    UnifiedSupportController(
      jobsRepository: jobs,
      clientsRepository: clients,
      engagementsRepository: engagements,
      shiftsRepository: shifts,
      visitsRepository: visits,
      session: session,
      args: args,
    ),
  );
}

void main() {
  late _MockJobsRepository jobs;
  late _MockClientsRepository clients;
  late _MockEngagementsRepository engagements;
  late _MockShiftsRepository shifts;
  late _MockVisitsRepository visits;
  late _MockSessionService session;

  final benjamin = _client('benjamin-id', 'Benjamin Nguyen');
  final avery = _client('avery-id', 'Tier B Host Avery');

  setUp(() {
    Get.reset();
    jobs = _MockJobsRepository();
    clients = _MockClientsRepository();
    engagements = _MockEngagementsRepository();
    shifts = _MockShiftsRepository();
    visits = _MockVisitsRepository();
    session = _MockSessionService();

    when(() => session.hasPermission(any())).thenReturn(true);
    when(() => session.tenantId).thenReturn(RxnString());
    when(() => session.tenantTimezone).thenReturn(RxnString());
    when(() => clients.listSites(any())).thenAnswer((_) async => []);
    when(() => clients.getClientProfile(any())).thenAnswer(
      (_) async => const ClientProfileBundle(),
    );
    when(
      () => jobs.listFormTemplates(tenantLevel: true),
    ).thenAnswer((_) async => []);
    when(() => jobs.getOngoingSupport(any())).thenThrow(Exception('none'));
  });

  tearDown(Get.reset);

  test(
    're-entering compose replaces prior controller client from route args',
    () async {
      final first = _putComposer(
        jobs: jobs,
        clients: clients,
        engagements: engagements,
        shifts: shifts,
        visits: visits,
        session: session,
        args: UnifiedSupportArgs.forClient(
          benjamin,
          mode: UnifiedSupportMode.oneSession,
        ),
      );
      await first.load();
      expect(first.client.value?.id, benjamin.id);

      final second = _putComposer(
        jobs: jobs,
        clients: clients,
        engagements: engagements,
        shifts: shifts,
        visits: visits,
        session: session,
        args: UnifiedSupportArgs.forClient(
          avery,
          mode: UnifiedSupportMode.oneSession,
        ),
      );
      expect(identical(first, second), isFalse);
      await second.load();
      expect(second.client.value?.id, avery.id);
      expect(second.client.value?.fullName, 'Tier B Host Avery');
    },
  );

  test(
    'Get.put without delete keeps the prior client (regression guard)',
    () async {
      final first = Get.put(
        UnifiedSupportController(
          jobsRepository: jobs,
          clientsRepository: clients,
          engagementsRepository: engagements,
          shiftsRepository: shifts,
          visitsRepository: visits,
          session: session,
          args: UnifiedSupportArgs.forClient(
            benjamin,
            mode: UnifiedSupportMode.oneSession,
          ),
        ),
      );
      await first.load();

      // Same bug as the old binding: constructing a new controller is ignored.
      final reused = Get.put(
        UnifiedSupportController(
          jobsRepository: jobs,
          clientsRepository: clients,
          engagementsRepository: engagements,
          shiftsRepository: shifts,
          visitsRepository: visits,
          session: session,
          args: UnifiedSupportArgs.forClient(
            avery,
            mode: UnifiedSupportMode.oneSession,
          ),
        ),
      );
      expect(identical(first, reused), isTrue);
      expect(reused.client.value?.id, benjamin.id);
    },
  );
}
