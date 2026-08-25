import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/constants/app_permissions.dart';
import 'package:rostiq/core/errors/app_failure.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/billing/data/models/billing_models.dart';
import 'package:rostiq/features/engagements/data/repositories/engagements_repository.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';
import 'package:rostiq/features/payroll/data/repositories/payroll_repository.dart';
import 'package:rostiq/features/shifts/data/repositories/shifts_repository.dart';
import 'package:rostiq/features/visits/controllers/staff_visits_controller.dart';
import 'package:rostiq/features/visits/data/models/visit_models.dart';
import 'package:rostiq/features/visits/data/repositories/visits_repository.dart';

class _MockVisitsRepository extends Mock implements VisitsRepository {}

class _MockShiftsRepository extends Mock implements ShiftsRepository {}

class _MockJobsRepository extends Mock implements JobsRepository {}

class _MockEngagementsRepository extends Mock
    implements EngagementsRepository {}

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _MockSessionService extends Mock implements SessionService {}

class _MockPayrollRepository extends Mock implements PayrollRepository {}

final _now = DateTime.utc(2026, 8, 13, 9);

VisitOut _visit({
  String? supportItemCode,
  String? supportItemName,
  List<VisitTaskOut> tasks = const [],
}) {
  return VisitOut(
    id: 'visit-1',
    tenantId: 'tenant-1',
    jobId: 'job-1',
    contractorId: 'contractor-1',
    scheduledStart: _now,
    scheduledEnd: _now.add(const Duration(hours: 1)),
    status: 'scheduled',
    source: 'manual',
    latitude: 0,
    longitude: 0,
    geofenceRadiusM: 100,
    geofenceMode: 'informational',
    paymentStatus: 'unpaid',
    createdAt: _now,
    updatedAt: _now,
    supportItemCode: supportItemCode,
    supportItemName: supportItemName,
    tasks: tasks,
  );
}

VisitTaskOut _task({String? supportItemCode, int? billableMinutes}) {
  return VisitTaskOut(
    id: 'task-1',
    visitId: 'visit-1',
    title: 'Personal care',
    sortOrder: 0,
    isDone: false,
    supportItemCode: supportItemCode,
    billableMinutes: billableMinutes,
  );
}

void main() {
  late _MockVisitsRepository visits;
  late _MockShiftsRepository shifts;
  late _MockJobsRepository jobs;
  late _MockEngagementsRepository engagements;
  late _MockClientsRepository clients;
  late _MockSessionService session;
  late StaffVisitsController controller;

  setUpAll(() {
    registerFallbackValue(
      const SupportItemPatch(
        supportItemCode: '01_011_0107_1_1',
        supportItemName: 'Self care',
      ),
    );
    registerFallbackValue(
      const VisitTaskSupportItemPatch(supportItemCode: '01_011_0107_1_1'),
    );
    registerFallbackValue(
      const VisitPriceTierPatch(priceTierOverride: PriceTier.remote),
    );
    registerFallbackValue(
      const VisitTaskBillingPatch(billableMinutes: 90),
    );
  });

  setUp(() {
    Get.testMode = true;
    visits = _MockVisitsRepository();
    shifts = _MockShiftsRepository();
    jobs = _MockJobsRepository();
    engagements = _MockEngagementsRepository();
    clients = _MockClientsRepository();
    session = _MockSessionService();
    when(() => session.hasPermission(any())).thenReturn(true);
    when(() => session.hasPermission(AppPermissions.shiftsManage)).thenReturn(true);
    when(() => session.hasPermission(AppPermissions.shiftsRead)).thenReturn(true);
    when(() => session.tenantTimezone).thenReturn(RxnString());
    when(() => shifts.listShifts(from: any(named: 'from'), to: any(named: 'to')))
        .thenAnswer((_) async => []);
    when(() => jobs.listJobs()).thenAnswer((_) async => []);
    when(
      () => engagements.listTenantEngagements(),
    ).thenAnswer((_) async => []);
    controller = StaffVisitsController(
      repository: visits,
      shiftsRepository: shifts,
      jobsRepository: jobs,
      engagementsRepository: engagements,
      clientsRepository: clients,
      session: session,
    );
  });

  tearDown(Get.reset);

  test('canEditVisitSupportItem is true when scheduled and unpaid', () {
    controller.selected.value = _visit();
    expect(controller.canEditVisitSupportItem, isTrue);
  });

  test('canEditVisitSupportItem is false when payment is not unpaid', () {
    controller.selected.value = _visit().copyWith();
    controller.selected.value = VisitOut(
      id: 'visit-1',
      tenantId: 'tenant-1',
      jobId: 'job-1',
      contractorId: 'contractor-1',
      scheduledStart: _now,
      scheduledEnd: _now.add(const Duration(hours: 1)),
      status: 'scheduled',
      source: 'manual',
      latitude: 0,
      longitude: 0,
      geofenceRadiusM: 100,
      geofenceMode: 'informational',
      paymentStatus: 'paid',
      createdAt: _now,
      updatedAt: _now,
    );
    expect(controller.canEditVisitSupportItem, isFalse);
  });

  test('updateVisitSupportItem patches visit and syncs editor', () async {
    final initial = _visit();
    final updated = _visit(
      supportItemCode: '01_011_0107_1_1',
      supportItemName: 'Self care',
    );
    controller.selected.value = initial;
    controller.editingVisitSupportItemCode.value = initial.supportItemCode;
    controller.editingVisitSupportItemName.value = initial.supportItemName;

    when(
      () => visits.patchVisitSupportItem('visit-1', any()),
    ).thenAnswer((_) async => updated);

    await controller.updateVisitSupportItem(
      supportItemCode: '01_011_0107_1_1',
      supportItemName: 'Self care',
    );

    expect(controller.selected.value?.supportItemCode, '01_011_0107_1_1');
    expect(controller.editingVisitSupportItemCode.value, '01_011_0107_1_1');
  });

  test('updateVisitSupportItem reverts editor on invalid_visit_status', () async {
    controller.selected.value = _visit();
    controller.editingVisitSupportItemCode.value = null;
    controller.editingVisitSupportItemName.value = null;

    when(() => visits.patchVisitSupportItem(any(), any())).thenThrow(
      const AppFailure(
        code: 'invalid_visit_status',
        message: 'Cannot change support item after check-in or payment.',
        presentation: AppFailurePresentation.inline,
      ),
    );

    await controller.updateVisitSupportItem(
      supportItemCode: '01_011_0107_1_1',
      supportItemName: 'Self care',
    );

    expect(controller.editingVisitSupportItemCode.value, isNull);
    expect(controller.errorMessage.value, contains('check-in'));
  });

  test('updateVisitTaskSupportItem patches task in visit list', () async {
    final task = _task();
    final visit = _visit(tasks: [task]);
    final updatedTask = _task(supportItemCode: '01_011_0107_1_1');
    controller.selected.value = visit;
    controller.editingTaskSupportCodes[task.id] = task.supportItemCode;

    when(
      () => visits.patchVisitTaskSupportItem(
        visitId: 'visit-1',
        taskId: 'task-1',
        body: any(named: 'body'),
      ),
    ).thenAnswer((_) async => updatedTask);

    await controller.updateVisitTaskSupportItem(
      task: task,
      supportItemCode: '01_011_0107_1_1',
      supportItemName: 'Self care',
    );

    expect(
      controller.selected.value?.tasks.single.supportItemCode,
      '01_011_0107_1_1',
    );
    expect(controller.editingTaskSupportNames[task.id], 'Self care');
    verify(
      () => visits.patchVisitTaskSupportItem(
        visitId: 'visit-1',
        taskId: 'task-1',
        body: any(named: 'body'),
      ),
    ).called(1);
  });

  test('updateVisitTaskSupportItem keeps name when code already saved', () async {
    final task = _task(supportItemCode: '01_011_0107_1_1');
    controller.selected.value = _visit(tasks: [task]);

    await controller.updateVisitTaskSupportItem(
      task: task,
      supportItemCode: '01_011_0107_1_1',
      supportItemName: 'Assistance With Self-Care Activities',
    );

    expect(controller.editingTaskSupportCodes[task.id], '01_011_0107_1_1');
    expect(
      controller.editingTaskSupportNames[task.id],
      'Assistance With Self-Care Activities',
    );
    verifyNever(
      () => visits.patchVisitTaskSupportItem(
        visitId: any(named: 'visitId'),
        taskId: any(named: 'taskId'),
        body: any(named: 'body'),
      ),
    );
  });

  test('updateVisitPriceTier patches and syncs editor', () async {
    final updated = _visit();
    final withTier = VisitOut(
      id: 'visit-1',
      tenantId: 'tenant-1',
      jobId: 'job-1',
      contractorId: 'contractor-1',
      scheduledStart: _now,
      scheduledEnd: _now.add(const Duration(hours: 1)),
      status: 'scheduled',
      source: 'manual',
      latitude: 0,
      longitude: 0,
      geofenceRadiusM: 100,
      geofenceMode: 'informational',
      paymentStatus: 'unpaid',
      createdAt: _now,
      updatedAt: _now,
      priceTierOverride: PriceTier.remote,
    );
    controller.selected.value = updated;
    controller.editingPriceTierOverride.value = null;

    when(
      () => visits.patchVisitPriceTier('visit-1', any()),
    ).thenAnswer((_) async => withTier);

    await controller.updateVisitPriceTier(PriceTier.remote);

    expect(controller.selected.value?.priceTierOverride, PriceTier.remote);
    expect(controller.editingPriceTierOverride.value, PriceTier.remote);
  });

  test('updateVisitPriceTier blocks further edits after visit_already_exported', () async {
    controller.selected.value = _visit();
    controller.editingPriceTierOverride.value = null;

    when(() => visits.patchVisitPriceTier(any(), any())).thenThrow(
      const AppFailure(
        code: 'visit_already_exported',
        message: 'Already included in an export — void that export to rebill.',
        presentation: AppFailurePresentation.inline,
      ),
    );

    await controller.updateVisitPriceTier(PriceTier.national);

    expect(controller.priceTierEditBlocked.value, isTrue);
    expect(controller.canEditVisitPriceTier, isFalse);
    expect(controller.errorMessage.value, contains('export'));
  });

  test('updateVisitTaskBillableMinutes patches task billing', () async {
    final task = _task(supportItemCode: '01_011_0107_1_1');
    final visit = _visit(tasks: [task]);
    final updatedTask = VisitTaskOut(
      id: 'task-1',
      visitId: 'visit-1',
      title: 'Personal care',
      sortOrder: 0,
      isDone: false,
      supportItemCode: '01_011_0107_1_1',
      billableMinutes: 90,
    );
    controller.selected.value = visit;

    when(
      () => visits.patchVisitTaskBilling(
        visitId: 'visit-1',
        taskId: 'task-1',
        body: any(named: 'body'),
      ),
    ).thenAnswer((_) async => updatedTask);

    await controller.updateVisitTaskBillableMinutes(
      task: task,
      rawMinutes: '90',
    );

    expect(
      controller.selected.value?.tasks.single.billableMinutes,
      90,
    );
    verify(
      () => visits.patchVisitTaskBilling(
        visitId: 'visit-1',
        taskId: 'task-1',
        body: any(named: 'body'),
      ),
    ).called(1);
  });

  test('updateVisitTaskBillableMinutes rejects out of range values', () async {
    final task = _task(supportItemCode: '01_011_0107_1_1');
    controller.selected.value = _visit(tasks: [task]);

    await controller.updateVisitTaskBillableMinutes(
      task: task,
      rawMinutes: '2000',
    );

    expect(controller.errorMessage.value, contains('1440'));
    verifyNever(
      () => visits.patchVisitTaskBilling(
        visitId: any(named: 'visitId'),
        taskId: any(named: 'taskId'),
        body: any(named: 'body'),
      ),
    );
  });
}
