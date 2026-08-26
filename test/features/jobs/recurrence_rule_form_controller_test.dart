import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/features/jobs/controllers/jobs_controller.dart';
import 'package:rostiq/features/jobs/controllers/recurrence_rule_form_controller.dart';
import 'package:rostiq/features/jobs/data/models/job_models.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/engagements/data/repositories/engagements_repository.dart';
import 'package:rostiq/app/constants/app_permissions.dart';
import 'package:rostiq/core/services/session_service.dart';

class _MockJobsRepository extends Mock implements JobsRepository {}

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _MockEngagementsRepository extends Mock
    implements EngagementsRepository {}

class _MockSessionService extends Mock implements SessionService {}

class _FakeRecurrenceRuleCreateRequest extends Fake
    implements RecurrenceRuleCreateRequest {}

void main() {
  late _MockJobsRepository jobsRepository;
  late JobsController jobsController;
  late RecurrenceRuleFormController formController;

  setUpAll(() {
    registerFallbackValue(_FakeRecurrenceRuleCreateRequest());
  });

  setUp(() {
    Get.testMode = true;
    jobsRepository = _MockJobsRepository();
    final session = _MockSessionService();
    when(() => session.hasPermission(any())).thenReturn(true);
    when(() => session.hasPermission(AppPermissions.jobsManage)).thenReturn(true);
    when(() => jobsRepository.listJobs()).thenAnswer((_) async => []);
    when(() => jobsRepository.listFormTemplates()).thenAnswer((_) async => []);
    when(() => jobsRepository.listBranches()).thenAnswer((_) async => []);
    when(() => jobsRepository.listRecurrenceRules(any())).thenAnswer((_) async => []);
    jobsController = JobsController(
      repository: jobsRepository,
      clientsRepository: _MockClientsRepository(),
      engagementsRepository: _MockEngagementsRepository(),
      session: session,
    );
    Get.put(jobsController);
    formController = RecurrenceRuleFormController();
    formController.onInit();
  });

  tearDown(() {
    formController.onClose();
    Get.reset();
  });

  RecurrenceRuleOut _ruleOut({int requiredSlots = 1}) => RecurrenceRuleOut(
        id: 'rule-1',
        tenantId: 'tenant-1',
        jobId: 'job-1',
        requiredSlots: requiredSlots,
        rrule: 'FREQ=WEEKLY;BYDAY=MO',
        dtstart: DateTime.utc(2026, 8, 1),
        timeWindows: const [TimeWindow(startTime: '09:00', endTime: '12:00')],
        isActive: true,
        createdAt: DateTime.utc(2026, 8, 1),
        updatedAt: DateTime.utc(2026, 8, 1),
      );

  void _selectJob() {
    jobsController.selected.value = JobOut(
      id: 'job-1',
      tenantId: 'tenant-1',
      kind: 'standing',
      status: 'open',
      title: 'Support',
      geofenceRadiusM: 100,
      geofenceMode: 'informational',
      createdAt: DateTime.utc(2026, 8, 1),
      updatedAt: DateTime.utc(2026, 8, 1),
    );
  }

  test('syncAssignSlots pads and truncates while keeping picks', () {
    formController.syncAssignSlots(1);
    expect(formController.setContractorAt(0, 'contractor-1'), isTrue);
    formController.syncAssignSlots(3);
    expect(formController.selectedContractorIds, ['contractor-1', null, null]);
    formController.syncAssignSlots(1);
    expect(formController.selectedContractorIds, ['contractor-1']);
  });

  test('setContractorAt rejects duplicate without side effects', () {
    formController.syncAssignSlots(2);
    expect(formController.setContractorAt(0, 'contractor-1'), isTrue);
    expect(formController.setContractorAt(1, 'contractor-1'), isFalse);
    expect(formController.selectedContractorIds, ['contractor-1', null]);
  });

  test('filledContractorIds drops null Unfilled holes', () {
    formController.syncAssignSlots(3);
    formController.setContractorAt(0, 'contractor-1');
    formController.setContractorAt(2, 'contractor-2');
    expect(formController.filledContractorIds, ['contractor-1', 'contractor-2']);
  });

  test('save sends taskTemplate with optional support item codes', () async {
    formController.taskTitlesCtrl.text = 'Personal care\nTransport';
    formController.setTaskSupportItem(
      index: 0,
      supportItemCode: '01_011_0107_1_1',
      supportItemName: 'Self care',
    );

    when(
      () => jobsRepository.createRecurrenceRule(any(), any()),
    ).thenAnswer((_) async => _ruleOut());

    _selectJob();
    await formController.save();

    final captured =
        verify(
          () => jobsRepository.createRecurrenceRule('job-1', captureAny()),
        ).captured.single as RecurrenceRuleCreateRequest;
    expect(captured.taskTemplate, hasLength(2));
    expect(captured.taskTemplate[0].title, 'Personal care');
    expect(captured.taskTemplate[0].supportItemCode, '01_011_0107_1_1');
    expect(captured.taskTemplate[1].supportItemCode, isNull);
  });

  test('save posts contractor_ids for multi-slot picks', () async {
    formController.requiredSlots.value = 2;
    formController.syncAssignSlots(2);
    formController.setContractorAt(0, 'contractor-1');
    formController.setContractorAt(1, 'contractor-2');

    when(
      () => jobsRepository.createRecurrenceRule(any(), any()),
    ).thenAnswer((_) async => _ruleOut(requiredSlots: 2));

    _selectJob();
    await formController.save();

    final captured =
        verify(
          () => jobsRepository.createRecurrenceRule('job-1', captureAny()),
        ).captured.single as RecurrenceRuleCreateRequest;
    expect(captured.requiredSlots, 2);
    expect(captured.contractorIds, ['contractor-1', 'contractor-2']);
  });
}
