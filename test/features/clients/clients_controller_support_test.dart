import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/clients/controllers/clients_controller.dart';
import 'package:rostiq/features/clients/data/models/client_models.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/jobs/data/models/job_models.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _MockJobsRepository extends Mock implements JobsRepository {}

class _MockSessionService extends Mock implements SessionService {}

final _now = DateTime.utc(2026, 8, 13, 9);

final _client = ClientOut(
  id: 'client-1',
  tenantId: 'tenant-1',
  fullName: 'Sam Lee',
  status: 'active',
  metadata: const {},
  createdAt: _now,
  updatedAt: _now,
);

JobOut _job({
  required String id,
  String clientId = 'client-1',
  String kind = 'standing',
  String status = 'open',
}) {
  return JobOut(
    id: id,
    tenantId: 'tenant-1',
    clientId: clientId,
    kind: kind,
    status: status,
    title: '$id title',
    geofenceRadiusM: 100,
    geofenceMode: 'informational',
    createdAt: _now,
    updatedAt: _now,
  );
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
    controller = ClientsController(
      repository: clients,
      session: session,
      jobsRepository: jobs,
    );
  });

  tearDown(Get.reset);

  test('loadStandingJob keeps open standing job for the selected client',
      () async {
    controller.selected.value = _client;
    when(() => jobs.listJobs()).thenAnswer(
      (_) async => [
        _job(id: 'other', clientId: 'client-2'),
        _job(id: 'adhoc', kind: 'ad_hoc'),
        _job(id: 'closed', status: 'closed'),
        _job(id: 'standing-1'),
      ],
    );

    await controller.loadStandingJob();

    expect(controller.standingJob.value?.id, 'standing-1');
    expect(controller.hasOngoing, isTrue);
  });

  test('loadStandingJob clears when this client has no open standing job',
      () async {
    controller.selected.value = _client;
    when(() => jobs.listJobs()).thenAnswer(
      (_) async => [_job(id: 'other', clientId: 'client-2')],
    );

    await controller.loadStandingJob();

    expect(controller.standingJob.value, isNull);
    expect(controller.hasOngoing, isFalse);
  });
}
