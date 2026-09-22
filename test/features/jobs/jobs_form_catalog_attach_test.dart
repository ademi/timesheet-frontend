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

final _now = DateTime.utc(2026, 8, 13, 9);

JobOut _job() {
  return JobOut(
    id: 'job-1',
    tenantId: 'tenant-1',
    kind: 'standing',
    status: 'open',
    title: 'Support',
    geofenceRadiusM: 100,
    geofenceMode: 'informational',
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

  setUp(() {
    Get.testMode = true;
    jobs = _MockJobsRepository();
    clients = _MockClientsRepository();
    engagements = _MockEngagementsRepository();
    session = _MockSessionService();
    when(() => session.hasPermission(any())).thenReturn(true);
    when(
      () => session.hasPermission(AppPermissions.jobsManage),
    ).thenReturn(true);
    when(() => jobs.listJobs()).thenAnswer((_) async => []);
    when(() => jobs.listFormTemplates()).thenAnswer((_) async => []);
    when(() => clients.listClients()).thenAnswer((_) async => []);
    when(() => jobs.listBranches()).thenAnswer((_) async => []);
    when(() => engagements.listTenantEngagements()).thenAnswer((_) async => []);
    when(() => jobs.listFormCatalog('job-1')).thenAnswer((_) async => []);
    controller = JobsController(
      repository: jobs,
      clientsRepository: clients,
      engagementsRepository: engagements,
      session: session,
    );
    controller.selected.value = _job();
  });

  tearDown(Get.reset);

  test('attachFormTemplates posts once and does not toggle isSaving', () async {
    when(
      () => jobs.addFormCatalog('job-1', ['t1', 't2']),
    ).thenAnswer((_) async {});
    when(() => jobs.listFormCatalog('job-1')).thenAnswer(
      (_) async => [
        const JobFormCatalogOut(
          formTemplateId: 't1',
          name: 'Alpha',
          isActive: true,
        ),
        const JobFormCatalogOut(
          formTemplateId: 't2',
          name: 'Beta',
          isActive: true,
        ),
      ],
    );

    controller.pendingAttachIds.assignAll(['t1', 't2']);
    expect(controller.isSaving.value, isFalse);

    final future = controller.attachSelectedFormTemplates();
    expect(
      controller.isPending(JobsController.attachCatalogPendingKey),
      isTrue,
    );
    expect(controller.isSaving.value, isFalse);
    await future;

    verify(() => jobs.addFormCatalog('job-1', ['t1', 't2'])).called(1);
    expect(controller.isSaving.value, isFalse);
    expect(controller.pendingAttachIds, isEmpty);
    expect(controller.formCatalog, hasLength(2));
    expect(
      controller.isPending(JobsController.attachCatalogPendingKey),
      isFalse,
    );
  });
}
