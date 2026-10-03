import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/clients/data/models/client_models.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/jobs/data/models/job_models.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';
import 'package:rostiq/features/jobs/utils/recurrence_rrule_builder.dart';
import 'package:rostiq/features/rostering/data/composer_facade.dart';
import 'package:rostiq/features/rostering/data/composer_models.dart';
import 'package:rostiq/features/rostering/domain/occurrence_draft.dart';
import 'package:rostiq/features/rostering/domain/repeat_template_payload.dart';
import 'package:rostiq/features/rostering/domain/roster_composer_args.dart';
import 'package:rostiq/features/rostering/presentation/composer/roster_composer_controller.dart';
import 'package:rostiq/features/shifts/data/models/shift_models.dart';
import 'package:rostiq/features/shifts/data/repositories/shifts_repository.dart';

class _MockShiftsRepository extends Mock implements ShiftsRepository {}

class _MockJobsRepository extends Mock implements JobsRepository {}

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _MockSessionService extends Mock implements SessionService {}

RecurrenceRuleOut _rule({
  String id = 'rule-1',
  String publishPolicy = 'published',
  List<String> contractorIds = const [],
}) {
  return RecurrenceRuleOut(
    id: id,
    tenantId: 't1',
    jobId: 'job-1',
    contractorIds: contractorIds,
    requiredSlots: 2,
    workerCount: 2,
    publishPolicy: publishPolicy,
    rrule: 'FREQ=WEEKLY;BYDAY=MO',
    dtstart: DateTime.utc(2026, 10, 6),
    timeWindows: const [TimeWindow(startTime: '09:00', endTime: '12:00')],
    isActive: true,
    createdAt: DateTime.utc(2026, 10, 1),
    updatedAt: DateTime.utc(2026, 10, 1),
  );
}

void main() {
  group('RepeatTemplatePayload soft preferred', () {
    test('create body includes contractor_ids as soft preferred', () {
      final draft = OccurrenceDraft.group(
        jobId: 'job-1',
        participantIds: const ['c1'],
        place: const ShiftPlaceIn.clientSite('site-1'),
        scheduledStart: DateTime(2026, 10, 6, 9),
        scheduledEnd: DateTime(2026, 10, 6, 12),
        workerCount: 2,
        requiredSlots: 2,
        taskTemplate: const [
          TaskTemplateItem(title: 'Meds', sortOrder: 0),
        ],
      );
      final body = RepeatTemplatePayload.buildCreate(
        draft: draft,
        frequency: RecurrenceFrequency.weekly,
        weekdays: {DateTime.monday},
        startDate: DateTime(2026, 10, 6),
        endDate: DateTime(2027, 10, 6),
        publishPolicy: 'draft',
        preferredContractorIds: const ['w-soft-a', 'w-soft-b'],
        formOverrides: const [
          ShiftFormOverrideOut(
            formTemplateId: 'ft-1',
            action: 'add',
            isRequired: true,
            name: 'Note',
            isActive: true,
          ),
        ],
      );
      final json = body.toJson();
      expect(json['contractor_ids'], ['w-soft-a', 'w-soft-b']);
      expect(json['publish_policy'], 'draft');
      expect(json['worker_count'], 2);
      expect(json['place'], {'client_site_id': 'site-1'});
      expect(json['participants'][0]['participant_id'], 'c1');
      expect(json['form_overrides'][0]['form_template_id'], 'ft-1');
      expect(json['task_template'][0]['title'], 'Meds');
    });
  });

  group('RosterComposerController Stage C Repeat', () {
    late _MockShiftsRepository shifts;
    late _MockJobsRepository jobs;
    late _MockClientsRepository clients;
    late _MockSessionService session;
    late ComposerFacade facade;

    setUpAll(() {
      registerFallbackValue(
        RecurrenceRuleCreateRequest(
          rrule: 'FREQ=WEEKLY;BYDAY=MO',
          dtstart: DateTime.utc(2026, 1, 1),
          timeWindows: const [
            TimeWindow(startTime: '09:00', endTime: '12:00'),
          ],
        ),
      );
      registerFallbackValue(const RecurrenceRulePatchRequest());
      registerFallbackValue(
        GenerateVisitsRequest(
          from: DateTime.utc(2026, 1, 1),
          to: DateTime.utc(2026, 1, 15),
        ),
      );
      registerFallbackValue(
        SplitRecurrenceRequest(
          fromDate: DateTime.utc(2026, 1, 1),
          timeWindows: const [
            TimeWindow(startTime: '09:00', endTime: '12:00'),
          ],
          horizonFrom: DateTime.utc(2026, 1, 1),
          horizonTo: DateTime.utc(2026, 1, 15),
        ),
      );
    });

    setUp(() {
      Get.reset();
      Get.testMode = true;
      shifts = _MockShiftsRepository();
      jobs = _MockJobsRepository();
      clients = _MockClientsRepository();
      session = _MockSessionService();
      facade = ComposerFacade(shifts: shifts, jobs: jobs);

      when(() => session.hasPermission(any())).thenReturn(true);
      when(
        () => session.tenantTimezone,
      ).thenReturn(RxnString('Australia/Sydney'));
      when(() => clients.listClients()).thenAnswer((_) async => <ClientOut>[]);
      when(
        () => shifts.fetchPlaceOptions(
          participantIds: any(named: 'participantIds'),
        ),
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
    });

    tearDown(Get.reset);

    RosterComposerController build() {
      final c = RosterComposerController(
        facade: facade,
        clientsRepository: clients,
        session: session,
        args: const RosterComposerArgs(
          preset: ComposerPreset.oneSession,
          clientId: 'c1',
          jobId: 'job-1',
          repeatEnabled: true,
        ),
      );
      Get.put(c);
      return c;
    }

    test('soft preferred contractor_ids land in create request body', () async {
      final c = build();
      await c.retryHydrate();
      c.draft.value = c.draft.value.copyWith(
        jobId: 'job-1',
        scheduledStart: DateTime(2026, 10, 6, 9),
        scheduledEnd: DateTime(2026, 10, 6, 12),
        participantIds: const ['c1'],
        place: const ShiftPlaceIn.clientSite('site-1'),
        requiredSlots: 2,
        workerCount: 2,
        repeatEnabled: true,
      );
      c.preferredContractorIds.assignAll(['w-a', 'w-b']);
      c.setRepeatPublishPolicy('draft');

      final json = c.buildRepeatCreateRequest().toJson();
      expect(json['contractor_ids'], ['w-a', 'w-b']);
      expect(json['publish_policy'], 'draft');
      expect(json.containsKey('contractor_id'), isFalse);
    });

    test('generate does not block shell (isSaving stays false)', () async {
      final createGate = Completer<RecurrenceRuleOut>();
      final generateGate = Completer<GenerateVisitsResponse>();

      when(() => jobs.createRecurrenceRule(any(), any())).thenAnswer(
        (_) => createGate.future,
      );
      when(
        () => jobs.generateVisits(
          jobId: any(named: 'jobId'),
          ruleId: any(named: 'ruleId'),
          body: any(named: 'body'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((_) => generateGate.future);

      final c = build();
      await c.retryHydrate();
      c.draft.value = c.draft.value.copyWith(
        jobId: 'job-1',
        scheduledStart: DateTime(2026, 10, 6, 9),
        scheduledEnd: DateTime(2026, 10, 6, 12),
        participantIds: const ['c1'],
        place: const ShiftPlaceIn.clientSite('site-1'),
        requiredSlots: 1,
        workerCount: 1,
        repeatEnabled: true,
      );
      c.preferredContractorIds.assignAll(['w-soft']);
      c.setRepeatPublishPolicy('published');

      final genFuture = c.generateRepeatHorizon();

      // Progress flag flips without taking the save-draft lock.
      await Future<void>.delayed(Duration.zero);
      expect(c.isGeneratingRepeat.value, isTrue);
      expect(c.isSaving.value, isFalse);

      // Shell stays interactive while generate is in flight.
      c.setRepeatFrequency(RecurrenceFrequency.fortnightly);
      expect(c.repeatFrequency.value, RecurrenceFrequency.fortnightly);
      expect(c.isSaving.value, isFalse);

      createGate.complete(_rule(contractorIds: const ['w-soft']));
      await Future<void>.delayed(Duration.zero);
      expect(c.isSaving.value, isFalse);

      generateGate.complete(
        const GenerateVisitsResponse(
          createdVisitIds: [],
          createdShiftIds: ['s1', 's2'],
        ),
      );
      await genFuture;

      expect(c.isGeneratingRepeat.value, isFalse);
      expect(c.isSaving.value, isFalse);
      expect(c.generateOutcomeMessage.value, contains('open'));
      expect(c.generateOutcomeMessage.value, contains('claim'));
    });

    test('this-and-future calls split endpoint', () async {
      when(
        () => jobs.splitRecurrenceFrom(
          jobId: any(named: 'jobId'),
          ruleId: any(named: 'ruleId'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => SplitRecurrenceOut(
          oldRule: _rule(id: 'rule-old'),
          newRule: _rule(id: 'rule-new', publishPolicy: 'draft'),
          horizon: HorizonOut.empty,
        ),
      );

      final c = build();
      await c.retryHydrate();
      c.draft.value = c.draft.value.copyWith(
        jobId: 'job-1',
        scheduledStart: DateTime(2026, 10, 13, 10),
        scheduledEnd: DateTime(2026, 10, 13, 13),
        requiredSlots: 2,
        workerCount: 2,
        repeatEnabled: true,
      );
      c.recurrenceRuleId.value = 'rule-old';
      c.preferredContractorIds.assignAll(['w-a']);

      final ok = await c.splitThisAndFuture();
      expect(ok, isTrue);
      expect(c.recurrenceRuleId.value, 'rule-new');
      verify(
        () => jobs.splitRecurrenceFrom(
          jobId: 'job-1',
          ruleId: 'rule-old',
          body: any(named: 'body'),
        ),
      ).called(1);
    });
  });
}
