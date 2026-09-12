import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/errors/app_failure.dart';
import 'package:rostiq/features/billing/data/models/billing_models.dart';
import 'package:rostiq/features/billing/data/repositories/ndis_catalogue_repository.dart';
import 'package:rostiq/features/jobs/data/models/job_models.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';
import 'package:rostiq/features/shifts/data/models/shift_models.dart';
import 'package:rostiq/features/shifts/data/repositories/shifts_repository.dart';
import 'package:rostiq/features/shifts/group_publish/group_shift_publish_args.dart';
import 'package:rostiq/features/shifts/group_publish/group_shift_publish_controller.dart';
import 'package:rostiq/features/shifts/group_publish/group_shift_publish_override_view.dart';
import 'package:rostiq/features/shifts/utils/publish_draft.dart';

class _MockShiftsRepository extends Mock implements ShiftsRepository {}

class _MockJobsRepository extends Mock implements JobsRepository {}

class _MockCatalogueRepository extends Mock
    implements NdisCatalogueRepository {}

class _FakeShiftPublishRequest extends Fake implements ShiftPublishRequest {}

final _now = DateTime.utc(2026, 9, 12, 9);

ShiftParticipantOut _participant({
  required String id,
  required String participantId,
  required String name,
  double allocationValue = 50,
}) {
  return ShiftParticipantOut(
    id: id,
    participantId: participantId,
    participantName: name,
    status: 'active',
    allocationStrategy: 'percentage',
    allocationValue: allocationValue,
  );
}

ShiftOut _shift({List<ShiftParticipantOut>? participants}) {
  return ShiftOut(
    id: 'shift-1',
    tenantId: 'tenant-1',
    jobId: 'job-1',
    jobTitle: 'Host House support',
    clientId: 'host-1',
    clientName: 'Host House',
    scheduledStart: _now,
    scheduledEnd: _now.add(const Duration(hours: 3)),
    requiredSlots: 1,
    openSlots: 1,
    workerCount: 1,
    status: 'draft',
    participants: participants ??
        [
          _participant(id: 'sp-1', participantId: 'p1', name: 'Maya'),
          _participant(id: 'sp-2', participantId: 'p2', name: 'Jordan'),
        ],
    createdAt: _now,
    updatedAt: _now,
  );
}

JobOut _job({String? supportItemCode}) {
  return JobOut(
    id: 'job-1',
    tenantId: 'tenant-1',
    kind: 'standing',
    status: 'open',
    title: 'Host House support',
    geofenceRadiusM: 100,
    geofenceMode: 'informational',
    createdAt: _now,
    updatedAt: _now,
    clientId: 'host-1',
    supportItemCode: supportItemCode,
    supportItemName: supportItemCode == null ? null : 'Assistance',
  );
}

NdisCatalogueItemOut _cat(String code, String price) {
  return NdisCatalogueItemOut(
    supportItemNumber: code,
    supportItemName: 'Item $code',
    supportCategoryNumber: '1',
    registrationGroupNumber: '0107',
    quoteRequired: false,
    priceLimitNational: price,
  );
}

void main() {
  late _MockShiftsRepository shifts;
  late _MockJobsRepository jobs;
  late _MockCatalogueRepository catalogue;

  setUpAll(() {
    registerFallbackValue(_FakeShiftPublishRequest());
  });

  setUp(() {
    Get.testMode = true;
    shifts = _MockShiftsRepository();
    jobs = _MockJobsRepository();
    catalogue = _MockCatalogueRepository();
  });

  tearDown(Get.reset);

  Future<GroupShiftPublishController> build({
    ShiftOut? shift,
    void Function(dynamic result)? onPop,
    Future<PublishParticipantOverrideDraft?> Function(
      GroupShiftPublishOverrideArgs args,
    )?
    openOverrideEditor,
  }) async {
    when(() => jobs.getJob('job-1')).thenAnswer(
      (_) async => _job(supportItemCode: '01_011_0107_1_1'),
    );
    when(() => catalogue.fetchAllActiveItems()).thenAnswer(
      (_) async => [
        _cat('01_011_0107_1_1', '67.56'),
        _cat('01_058_0115_1_1', '162.85'),
        _cat('01_012_0107_1_1', '80.00'),
      ],
    );

    final c = GroupShiftPublishController(
      shiftsRepository: shifts,
      jobsRepository: jobs,
      catalogueRepository: catalogue,
      args: GroupShiftPublishArgs(shift: shift ?? _shift()),
      onPop: onPop,
      openOverrideEditor: openOverrideEditor,
    );
    c.onInit();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    return c;
  }

  test('prefills default item from job and loads catalogue once', () async {
    final c = await build();
    expect(c.draft.value.supportItemCode, '01_011_0107_1_1');
    expect(c.catalogueNationalByCode['01_011_0107_1_1'], 67.56);
    verify(() => catalogue.fetchAllActiveItems()).called(1);
    verifyNever(() => catalogue.searchItems(q: any(named: 'q')));
  });

  test('blocks Next on item step without default item', () async {
    when(() => jobs.getJob('job-1')).thenAnswer((_) async => _job());
    when(() => catalogue.fetchAllActiveItems()).thenAnswer((_) async => []);
    final c = GroupShiftPublishController(
      shiftsRepository: shifts,
      jobsRepository: jobs,
      catalogueRepository: catalogue,
      args: GroupShiftPublishArgs(shift: _shift()),
    );
    c.onInit();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(c.draft.value.supportItemCode, isNull);
    c.nextStep();
    expect(c.step.value, 0);
    expect(c.errorMessage.value, contains('default'));
  });

  test('steps Item → People → Stay → Review', () async {
    final c = await build();
    expect(c.step.value, GroupShiftPublishController.itemStep);
    c.nextStep();
    expect(c.step.value, GroupShiftPublishController.peopleStep);
    c.nextStep();
    expect(c.step.value, GroupShiftPublishController.stayStep);
    c.nextStep();
    expect(c.step.value, GroupShiftPublishController.reviewStep);
  });

  test('override merges into publish body; busy guards double publish', () async {
    ShiftPublishRequest? captured;
    when(
      () => shifts.publishShift('shift-1', body: any(named: 'body')),
    ).thenAnswer((invocation) async {
      captured = invocation.namedArguments[#body] as ShiftPublishRequest?;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return _shift().copyWithStatus('published');
    });

    dynamic popped;
    final c = await build(
      onPop: (r) => popped = r,
      openOverrideEditor: (_) async {
        return const PublishParticipantOverrideDraft(
          participantId: 'p2',
          supportItemCode: '01_012_0107_1_1',
          baseRate: 70,
          reason: 'High intensity',
        );
      },
    );

    await c.openCustomOverride(c.active[1]);
    expect(c.draft.value.hasCustom('p2'), isTrue);

    c.step.value = GroupShiftPublishController.reviewStep;
    final first = c.publish();
    final second = c.publish();
    await Future.wait([first, second]);

    verify(
      () => shifts.publishShift('shift-1', body: any(named: 'body')),
    ).called(1);
    expect(captured?.participantOverrides, hasLength(1));
    expect(captured?.participantOverrides!.single.participantId, 'p2');
    expect(captured?.participantOverrides!.single.baseRate, 70);
    expect(popped, isA<ShiftOut>());
  });

  test('accommodation fields included when Stay on', () async {
    ShiftPublishRequest? captured;
    when(
      () => shifts.publishShift('shift-1', body: any(named: 'body')),
    ).thenAnswer((invocation) async {
      captured = invocation.namedArguments[#body] as ShiftPublishRequest?;
      return _shift().copyWithStatus('published');
    });

    final c = await build(onPop: (_) {});
    c.setAccommodationEnabled(true);
    c.setAccommodationItem(
      supportItemCode: '01_058_0115_1_1',
      supportItemName: 'STA day',
    );
    c.setAccommodationQuantity('2');
    c.step.value = GroupShiftPublishController.reviewStep;
    await c.publish();

    expect(captured?.accommodationSupportItemCode, '01_058_0115_1_1');
    expect(captured?.accommodationQuantity, '2');
  });

  test('publish error stays on Review with message', () async {
    when(
      () => shifts.publishShift('shift-1', body: any(named: 'body')),
    ).thenThrow(
      const AppFailure(
        code: 'validation_error',
        message: '422 validation',
        presentation: AppFailurePresentation.toast,
      ),
    );

    final c = await build();
    c.step.value = GroupShiftPublishController.reviewStep;
    await c.publish();

    expect(c.step.value, GroupShiftPublishController.reviewStep);
    expect(c.errorMessage.value, '422 validation');
    expect(c.isSaving.value, isFalse);
  });

  test('Stay off omits accommodation from request', () async {
    ShiftPublishRequest? captured;
    when(
      () => shifts.publishShift('shift-1', body: any(named: 'body')),
    ).thenAnswer((invocation) async {
      captured = invocation.namedArguments[#body] as ShiftPublishRequest?;
      return _shift().copyWithStatus('published');
    });

    final c = await build(onPop: (_) {});
    c.setAccommodationEnabled(true);
    c.setAccommodationItem(
      supportItemCode: '01_058_0115_1_1',
      supportItemName: 'STA',
    );
    c.setAccommodationQuantity('1');
    c.setAccommodationEnabled(false);
    c.step.value = GroupShiftPublishController.reviewStep;
    await c.publish();

    final json = captured!.toJson();
    expect(json, isNot(contains('accommodation_support_item_code')));
  });

  test('disabling Stay clears qty; re-enable defaults to 1', () async {
    final c = await build();
    c.setAccommodationEnabled(true);
    c.setAccommodationQuantity('3');
    expect(c.draft.value.accommodationQuantity, '3');

    c.setAccommodationEnabled(false);
    expect(c.draft.value.accommodationEnabled, isFalse);
    expect(c.draft.value.accommodationQuantity, isNull);

    c.setAccommodationEnabled(true);
    expect(c.draft.value.accommodationQuantity, '1');
  });
}

extension on ShiftOut {
  ShiftOut copyWithStatus(String status) {
    return ShiftOut(
      id: id,
      tenantId: tenantId,
      jobId: jobId,
      jobTitle: jobTitle,
      clientId: clientId,
      clientName: clientName,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      requiredSlots: requiredSlots,
      openSlots: openSlots,
      workerCount: workerCount,
      status: status,
      recurrenceRuleId: recurrenceRuleId,
      locationLabel: locationLabel,
      suburb: suburb,
      postalCode: postalCode,
      assignments: assignments,
      participants: participants,
      warnings: warnings,
      accommodationSupportItemCode: accommodationSupportItemCode,
      accommodationQuantity: accommodationQuantity,
      publishedAt: publishedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
