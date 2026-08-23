import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/constants/app_permissions.dart';
import 'package:rostiq/core/errors/app_failure.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/billing/data/models/billing_models.dart';
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

class _FakeJobCreateRequest extends Fake implements JobCreateRequest {}

final _now = DateTime.utc(2026, 8, 13, 9);

JobOut _job({
  String? supportItemCode,
  String? supportItemName,
}) {
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
    supportItemCode: supportItemCode,
    supportItemName: supportItemName,
  );
}

void main() {
  late _MockJobsRepository jobs;
  late _MockClientsRepository clients;
  late _MockEngagementsRepository engagements;
  late _MockSessionService session;
  late JobsController controller;

  setUpAll(() {
    registerFallbackValue(_FakeJobCreateRequest());
    registerFallbackValue(
      const SupportItemPatch(
        supportItemCode: '01_011_0107_1_1',
        supportItemName: 'Self care',
      ),
    );
  });

  setUp(() {
    Get.testMode = true;
    jobs = _MockJobsRepository();
    clients = _MockClientsRepository();
    engagements = _MockEngagementsRepository();
    session = _MockSessionService();
    when(() => session.hasPermission(any())).thenReturn(true);
    when(() => session.hasPermission(AppPermissions.jobsManage)).thenReturn(true);
    when(() => jobs.listJobs()).thenAnswer((_) async => []);
    when(() => jobs.listFormTemplates()).thenAnswer((_) async => []);
    when(() => clients.listClients()).thenAnswer((_) async => []);
    when(() => jobs.listBranches()).thenAnswer((_) async => []);
    when(() => engagements.listTenantEngagements()).thenAnswer((_) async => []);
    controller = JobsController(
      repository: jobs,
      clientsRepository: clients,
      engagementsRepository: engagements,
      session: session,
    );
  });

  tearDown(Get.reset);

  test('saveJob includes optional support item pair', () async {
    controller.titleCtrl.text = 'New support';
    controller.kind.value = 'ad_hoc';
    controller.locationMode.value = 'branch';
    controller.selectedBranchId.value = 'branch-1';
    controller.setCreateSupportItem(
      supportItemCode: '01_011_0107_1_1',
      supportItemName: 'Self care',
    );
    when(() => jobs.createJob(any())).thenAnswer((_) async => _job());

    await controller.saveJob();

    final captured =
        verify(() => jobs.createJob(captureAny())).captured.single
            as JobCreateRequest;
    expect(captured.supportItemCode, '01_011_0107_1_1');
    expect(captured.supportItemName, 'Self care');
  });

  test('updateJobSupportItem patches and refreshes selected job', () async {
    final initial = _job();
    final updated = _job(
      supportItemCode: '01_011_0107_1_1',
      supportItemName: 'Self care',
    );
    controller.selected.value = initial;
    controller.editingSupportItemCode.value = initial.supportItemCode;
    controller.editingSupportItemName.value = initial.supportItemName;

    when(
      () => jobs.patchJobSupportItem(
        'job-1',
        any(),
      ),
    ).thenAnswer((_) async => updated);

    await controller.updateJobSupportItem(
      supportItemCode: '01_011_0107_1_1',
      supportItemName: 'Self care',
    );

    expect(controller.selected.value?.supportItemCode, '01_011_0107_1_1');
    expect(controller.editingSupportItemCode.value, '01_011_0107_1_1');
    verify(() => jobs.patchJobSupportItem('job-1', any())).called(1);
  });

  test('updateJobSupportItem reverts picker state on failure', () async {
    final initial = _job();
    controller.selected.value = initial;
    controller.editingSupportItemCode.value = initial.supportItemCode;
    controller.editingSupportItemName.value = initial.supportItemName;

    when(() => jobs.patchJobSupportItem(any(), any())).thenThrow(
      const AppFailure(
        code: 'support_item_not_in_catalogue',
        message: 'Item not in the current NDIS catalogue.',
        presentation: AppFailurePresentation.inline,
      ),
    );

    await controller.updateJobSupportItem(
      supportItemCode: '01_011_0107_1_1',
      supportItemName: 'Self care',
    );

    expect(controller.selected.value?.supportItemCode, isNull);
    expect(controller.editingSupportItemCode.value, isNull);
    expect(controller.errorMessage.value, contains('catalogue'));
  });
}
