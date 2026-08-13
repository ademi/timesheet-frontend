import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/constants/app_permissions.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/engagements/data/repositories/engagements_repository.dart';
import 'package:rostiq/features/jobs/controllers/jobs_controller.dart';
import 'package:rostiq/features/jobs/data/models/job_models.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';

class _MockJobsRepository extends Mock implements JobsRepository {}

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _MockEngagementsRepository extends Mock
    implements EngagementsRepository {}

class _MockSessionService extends Mock implements SessionService {}

class _FakeHorizonRequest extends Fake implements HorizonRequest {}

final _now = DateTime.utc(2026, 8, 13, 9);

JobOut _job() {
  return JobOut(
    id: 'job-1',
    tenantId: 'tenant-1',
    clientId: 'client-1',
    kind: 'standing',
    status: 'open',
    title: 'Support',
    geofenceRadiusM: 100,
    geofenceMode: 'informational',
    createdAt: _now,
    updatedAt: _now,
  );
}

RecurrenceRuleOut _rule({required String id, required bool isActive}) {
  return RecurrenceRuleOut(
    id: id,
    tenantId: 'tenant-1',
    jobId: 'job-1',
    requiredSlots: 1,
    rrule: 'FREQ=WEEKLY',
    dtstart: _now,
    timeWindows: const [],
    isActive: isActive,
    createdAt: _now,
    updatedAt: _now,
  );
}

void main() {
  late _MockJobsRepository jobs;
  late _MockClientsRepository clients;
  late _MockEngagementsRepository engagements;
  late _MockSessionService session;
  late JobsController controller;

  setUpAll(() {
    registerFallbackValue(_FakeHorizonRequest());
  });

  setUp(() {
    Get.testMode = true;
    Get.reset();
    jobs = _MockJobsRepository();
    clients = _MockClientsRepository();
    engagements = _MockEngagementsRepository();
    session = _MockSessionService();
    when(() => session.hasPermission(any())).thenReturn(true);
    controller = JobsController(
      repository: jobs,
      clientsRepository: clients,
      engagementsRepository: engagements,
      session: session,
    );
    controller.selected.value = _job();
  });

  tearDown(Get.reset);

  test('canFillHorizon is false when there are no active rules', () {
    controller.rules.assignAll([_rule(id: 'r1', isActive: false)]);
    expect(controller.canFillHorizon, isFalse);
  });

  test('canFillHorizon is true when an active rule exists', () {
    controller.rules.assignAll([_rule(id: 'r1', isActive: true)]);
    expect(controller.canFillHorizon, isTrue);
  });

  test('fillNext14Days does not POST when there are no active rules', () async {
    controller.rules.assignAll([_rule(id: 'r1', isActive: false)]);
    await controller.fillNext14Days();
    verifyNever(() => jobs.ensureHorizon(any()));
  });

  test(
    'fillNext14Days posts horizon for active rule ids in a 14-day window',
    () async {
      controller.rules.assignAll([
        _rule(id: 'r-active', isActive: true),
        _rule(id: 'r-paused', isActive: false),
      ]);
      when(
        () => jobs.ensureHorizon(any()),
      ).thenAnswer((_) async => HorizonOut.empty);

      await controller.fillNext14Days();

      final req =
          verify(() => jobs.ensureHorizon(captureAny())).captured.single
              as HorizonRequest;
      expect(req.ruleIds, ['r-active']);
      expect(req.to.difference(req.from), const Duration(days: 14));
      final now = DateTime.now();
      expect(req.from, DateTime(now.year, now.month, now.day).toUtc());
    },
  );

  test('fillNext14Days skips without jobs.manage', () async {
    when(() => session.hasPermission(any())).thenAnswer((invocation) {
      final perm = invocation.positionalArguments.first as String;
      return perm != AppPermissions.jobsManage;
    });
    controller.rules.assignAll([_rule(id: 'r1', isActive: true)]);
    await controller.fillNext14Days();
    verifyNever(() => jobs.ensureHorizon(any()));
  });
}
