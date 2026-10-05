import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/getx/put_fresh.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/clients/bindings/client_onboarding_binding.dart';
import 'package:rostiq/features/clients/controllers/client_onboarding_controller.dart';
import 'package:rostiq/features/clients/controllers/support_plan_controller.dart';
import 'package:rostiq/features/clients/data/models/client_models.dart';
import 'package:rostiq/features/clients/data/models/client_profile_models.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';
import 'package:rostiq/features/rostering/data/composer_facade.dart';
import 'package:rostiq/features/rostering/domain/roster_composer_args.dart';
import 'package:rostiq/features/rostering/presentation/composer/roster_composer_controller.dart';
import 'package:rostiq/features/shifts/data/models/shift_models.dart';
import 'package:rostiq/features/shifts/data/repositories/shifts_repository.dart';
import 'package:rostiq/features/sil/controllers/sil_houses_controller.dart';
import 'package:rostiq/features/sil/data/models/sil_models.dart';
import 'package:rostiq/features/sil/data/repositories/sil_repository.dart';

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _MockSessionService extends Mock implements SessionService {}

class _MockJobsRepository extends Mock implements JobsRepository {}

class _MockShiftsRepository extends Mock implements ShiftsRepository {}

class _MockSilRepository extends Mock implements SilRepository {}

ClientOut _client(String id) => ClientOut(
  id: id,
  tenantId: 'tenant-1',
  fullName: 'Client $id',
  status: 'active',
  metadata: const {},
  createdAt: DateTime.utc(2026, 10, 1),
  updatedAt: DateTime.utc(2026, 10, 1),
);

ShiftOut _shift(String id) {
  final now = DateTime.utc(2026, 10, 4, 9);
  return ShiftOut(
    id: id,
    tenantId: 'tenant-1',
    jobId: 'job-1',
    jobTitle: 'Group support',
    clientId: 'host-1',
    clientName: 'Host',
    scheduledStart: now,
    scheduledEnd: now.add(const Duration(hours: 3)),
    requiredSlots: 1,
    openSlots: 1,
    status: 'draft',
    createdAt: now,
    updatedAt: now,
  );
}

SilHouseBundleOut _bundle(String houseId) => SilHouseBundleOut(
  house: SilHouseOut(
    id: houseId,
    tenantId: 'tenant-1',
    name: 'House $houseId',
  ),
  members: const [],
  rocBlocks: const [],
  presentOccupancy: 0,
);

void main() {
  late _MockClientsRepository clients;
  late _MockSessionService session;
  late _MockJobsRepository jobs;
  late _MockShiftsRepository shifts;
  late _MockSilRepository sil;
  late ComposerFacade facade;

  setUp(() {
    Get.reset();
    Get.testMode = true;
    clients = _MockClientsRepository();
    session = _MockSessionService();
    jobs = _MockJobsRepository();
    shifts = _MockShiftsRepository();
    sil = _MockSilRepository();
    facade = ComposerFacade(shifts: shifts, jobs: jobs);
    when(() => session.hasPermission(any())).thenReturn(true);
    when(() => session.tenantTimezone).thenReturn(RxnString());
    when(() => clients.listSupportPlans(any())).thenAnswer((_) async => []);
    when(() => clients.getBudgetSummary(any())).thenThrow(Exception('skip'));
    when(
      () => clients.getClientProfile(any()),
    ).thenAnswer((_) async => const ClientProfileBundle());
    when(() => clients.listClients()).thenAnswer((_) async => []);
    when(() => sil.getHouse(any())).thenAnswer(
      (inv) async => _bundle(inv.positionalArguments.first as String),
    );
    when(() => sil.getOverlay(any())).thenThrow(Exception('no overlay'));
    when(() => sil.listCompatRules(any())).thenAnswer((_) async => []);
  });

  tearDown(Get.reset);

  group('SupportPlanController', () {
    test('putFresh replaces prior clientId (route re-enter)', () {
      final first = putFresh(
        () => SupportPlanController(
          repository: clients,
          session: session,
          clientId: 'client-a',
        ),
      );
      expect(first.clientId, 'client-a');

      final second = putFresh(
        () => SupportPlanController(
          repository: clients,
          session: session,
          clientId: 'client-b',
        ),
      );
      expect(identical(first, second), isFalse);
      expect(Get.find<SupportPlanController>().clientId, 'client-b');
    });
  });

  group('RosterComposerController', () {
    test('putFresh replaces prior args (composer cutover re-enter)', () {
      final first = putFresh(
        () => RosterComposerController(
          facade: facade,
          clientsRepository: clients,
          session: session,
          args: RosterComposerArgs(
            shiftId: 'shift-a',
            shift: _shift('shift-a'),
            focusSection: ComposerFocusSection.people,
          ),
          onNavigate: (_, __) {},
        ),
      );
      expect(first.focusSection.value, ComposerFocusSection.people);

      final second = putFresh(
        () => RosterComposerController(
          facade: facade,
          clientsRepository: clients,
          session: session,
          args: RosterComposerArgs(
            shiftId: 'shift-b',
            shift: _shift('shift-b'),
            focusSection: ComposerFocusSection.publish,
          ),
          onNavigate: (_, __) {},
        ),
      );
      expect(identical(first, second), isFalse);
      expect(
        Get.find<RosterComposerController>().focusSection.value,
        ComposerFocusSection.publish,
      );
    });
  });

  group('SilHouseDetailController', () {
    test('putFresh replaces prior houseId (sticky lazyPut regression)', () async {
      final first = putFresh(
        () => SilHouseDetailController(sil, houseId: 'house-a'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(first.houseId, 'house-a');

      final second = putFresh(
        () => SilHouseDetailController(sil, houseId: 'house-b'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(identical(first, second), isFalse);
      expect(Get.find<SilHouseDetailController>().houseId, 'house-b');
    });
  });

  group('ClientOnboardingController', () {
    test('release deletes controller on route exit', () {
      Get.put(
        ClientOnboardingController(repository: clients, session: session),
      );
      expect(Get.isRegistered<ClientOnboardingController>(), isTrue);

      ClientOnboardingBinding.release();
      expect(Get.isRegistered<ClientOnboardingController>(), isFalse);
    });

    test('different incoming client id replaces prior controller', () {
      final first = Get.put(
        ClientOnboardingController(repository: clients, session: session),
      );
      first.client.value = _client('client-a');

      // Mirrors ClientOnboardingBinding.dependencies client-switch branch.
      const incomingId = 'client-b';
      final existingId = Get.find<ClientOnboardingController>().client.value?.id;
      if (incomingId != existingId) {
        Get.delete<ClientOnboardingController>(force: true);
      }
      final second = Get.put(
        ClientOnboardingController(repository: clients, session: session),
      );

      expect(identical(first, second), isFalse);
      expect(second.client.value, isNull);
    });

    test('same client id keeps controller (step URL sync)', () {
      final first = Get.put(
        ClientOnboardingController(repository: clients, session: session),
      );
      first.client.value = _client('client-a');
      first.step.value = 2;

      const incomingId = 'client-a';
      final existingId = Get.find<ClientOnboardingController>().client.value?.id;
      if (incomingId != existingId) {
        Get.delete<ClientOnboardingController>(force: true);
      }

      expect(Get.isRegistered<ClientOnboardingController>(), isTrue);
      expect(identical(Get.find<ClientOnboardingController>(), first), isTrue);
      expect(first.step.value, 2);
    });
  });
}
