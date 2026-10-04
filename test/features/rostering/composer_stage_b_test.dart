import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/clients/data/models/client_models.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/jobs/data/models/job_models.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';
import 'package:rostiq/features/rostering/data/composer_facade.dart';
import 'package:rostiq/features/rostering/data/composer_models.dart';
import 'package:rostiq/features/rostering/domain/occurrence_draft.dart';
import 'package:rostiq/features/rostering/domain/roster_composer_args.dart';
import 'package:rostiq/features/rostering/domain/travel_shares_validation.dart';
import 'package:rostiq/features/rostering/presentation/composer/roster_composer_controller.dart';
import 'package:rostiq/features/rostering/presentation/shared/assign_context_labels.dart';
import 'package:rostiq/features/shifts/data/models/shift_travel_models.dart';
import 'package:rostiq/features/shifts/data/repositories/shifts_repository.dart';
import 'package:rostiq/features/visits/data/models/roster_overlay_models.dart';
import 'package:rostiq/shared/models/profile_photo_models.dart';

class _MockShiftsRepository extends Mock implements ShiftsRepository {}

class _MockJobsRepository extends Mock implements JobsRepository {}

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _MockSessionService extends Mock implements SessionService {}

FormTemplateOut _template(String id, String name) => FormTemplateOut(
  id: id,
  tenantId: 't1',
  name: name,
  schemaJson: const {},
  isActive: true,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

void main() {
  group('TravelSharesValidation', () {
    test('explicit sum mismatch when shares do not total journey', () {
      expect(
        TravelSharesValidation.explicitSumMismatch(
          journeyMinutes: '60',
          shareMinutesByParticipant: const {'a': '20', 'b': '30'},
        ),
        contains('sum'),
      );
    });

    test('explicit sum ok when shares match', () {
      expect(
        TravelSharesValidation.explicitSumMismatch(
          journeyMinutes: '60',
          shareMinutesByParticipant: const {'a': '20', 'b': '40'},
        ),
        isNull,
      );
    });
  });

  group('AssignContextOut parse', () {
    test('parses lite rows, overlay, and client conflicts', () {
      final ctx = AssignContextOut.fromJson({
        'shifts_lite': [
          {
            'id': 's1',
            'job_id': 'j1',
            'contractor_ids': ['w1'],
            'scheduled_start': '2026-10-04T09:00:00Z',
            'scheduled_end': '2026-10-04T12:00:00Z',
          },
        ],
        'visits_lite': [
          {
            'id': 'v1',
            'client_id': 'c1',
            'contractor_id': 'w2',
            'scheduled_start': '2026-10-04T10:00:00Z',
            'scheduled_end': '2026-10-04T11:00:00Z',
          },
        ],
        'overlay': {
          'contractors': [
            {
              'contractor_id': 'w1',
              'display_name': 'Ada',
              'leave': [],
              'availability': [],
            },
          ],
        },
        'client_conflicts': [
          {
            'id': 'v2',
            'kind': 'visit',
            'client_id': 'c1',
            'scheduled_start': '2026-10-04T09:00:00Z',
            'scheduled_end': '2026-10-04T10:00:00Z',
          },
        ],
      });

      expect(ctx.shiftsLite, hasLength(1));
      expect(ctx.shiftsLite.first.contractorIds, ['w1']);
      expect(ctx.visitsLite.first.contractorId, 'w2');
      expect(ctx.overlay.contractors.first.displayName, 'Ada');
      expect(ctx.clientConflicts.first.kind, 'visit');
    });

    test('Busy label from overlapping lite visit', () {
      final ctx = AssignContextOut(
        visitsLite: [
          VisitLiteOut(
            id: 'v1',
            contractorId: 'w1',
            scheduledStart: DateTime.utc(2026, 10, 4, 9),
            scheduledEnd: DateTime.utc(2026, 10, 4, 12),
          ),
        ],
        overlay: const RosterOverlayOut(),
      );
      final label = assignAvailabilityLabelFromContext(
        contractorId: 'w1',
        day: DateTime(2026, 10, 4),
        shiftStart: DateTime.utc(2026, 10, 4, 10),
        shiftEnd: DateTime.utc(2026, 10, 4, 11),
        context: ctx,
      );
      expect(label, 'Busy');
      expect(assignLabelRequiresOverrideReason(label), isTrue);
    });
  });

  group('RosterComposerController Stage B', () {
    late _MockShiftsRepository shifts;
    late _MockJobsRepository jobs;
    late _MockClientsRepository clients;
    late _MockSessionService session;
    late ComposerFacade facade;
    String? lastPromptLabel;

    setUpAll(() {
      registerFallbackValue(
        const FormPreviewRequirementsRequest(jobId: 'j'),
      );
      registerFallbackValue(<ShiftFormOverrideOut>[]);
    });

    setUp(() {
      Get.reset();
      Get.testMode = true;
      lastPromptLabel = null;
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
        () => clients.getClientProfilePhoto(any()),
      ).thenAnswer((_) async => const ProfilePhotoOut());
      when(
        () => shifts.fetchPlaceOptions(
          participantIds: any(named: 'participantIds'),
        ),
      ).thenAnswer((_) async => const PlaceOptionsOut());
      when(
        () => jobs.listFormTemplates(tenantLevel: any(named: 'tenantLevel')),
      ).thenAnswer(
        (_) async => [_template('ft-1', 'Progress note'), _template('ft-2', 'Incident')],
      );
      when(() => shifts.previewForms(any())).thenAnswer(
        (_) async => [
          const ResolvedFormPreviewOut(
            formTemplateId: 'ft-2',
            name: 'Incident',
            isRequired: true,
            source: 'override',
          ),
        ],
      );
      when(
        () => shifts.putFormOverrides(any(), any()),
      ).thenAnswer((inv) async => inv.positionalArguments[1] as List<ShiftFormOverrideOut>);
    });

    tearDown(Get.reset);

    RosterComposerController build({
      Future<String?> Function({required String label})? prompt,
    }) {
      final c = RosterComposerController(
        facade: facade,
        clientsRepository: clients,
        session: session,
        args: const RosterComposerArgs(
          preset: ComposerPreset.oneSession,
          clientId: 'c1',
        ),
        promptAssignOverrideReason: prompt,
      );
      Get.put(c);
      return c;
    }

    test('form override add/remove triggers preview, never addFormCatalog', () async {
      final c = build();
      await c.retryHydrate();
      c.draft.value = c.draft.value.copyWith(jobId: 'job-1', shiftId: 'shift-1');

      c.addFormOverride(_template('ft-2', 'Incident'));
      expect(c.formOverrides, hasLength(1));
      expect(c.formOverrides.first.action, 'add');

      await Future<void>.delayed(const Duration(milliseconds: 350));
      verify(() => shifts.previewForms(any())).called(1);
      verify(() => shifts.putFormOverrides('shift-1', any())).called(1);
      verifyNever(() => jobs.addFormCatalog(any(), any()));

      c.resolvedForms.assignAll([
        const ResolvedFormPreviewOut(
          formTemplateId: 'ft-1',
          name: 'Progress note',
          isRequired: true,
          source: 'org',
        ),
      ]);
      c.removeFormOverride('ft-1');
      expect(
        c.formOverrides.any((o) => o.action == 'remove' && o.formTemplateId == 'ft-1'),
        isTrue,
      );
    });

    test('busy override requires reason', () async {
      final c = build(
        prompt: ({required String label}) async {
          lastPromptLabel = label;
          return null; // cancel / empty
        },
      );
      await c.retryHydrate();
      c.draft.value = c.draft.value.copyWith(
        scheduledStart: DateTime(2026, 10, 4, 10),
        scheduledEnd: DateTime(2026, 10, 4, 12),
      );
      c.assignContext.value = AssignContextOut(
        visitsLite: [
          VisitLiteOut(
            id: 'v1',
            contractorId: 'w-busy',
            scheduledStart: DateTime(2026, 10, 4, 9),
            scheduledEnd: DateTime(2026, 10, 4, 13),
          ),
        ],
      );

      final rejected = await c.selectContractor('w-busy');
      expect(rejected, isFalse);
      expect(lastPromptLabel, 'Busy');
      expect(c.draft.value.contractorIds, isEmpty);

      final accepted = await c.selectContractor(
        'w-busy',
        overrideReason: 'Covering leave',
      );
      expect(accepted, isTrue);
      expect(c.draft.value.contractorIds, ['w-busy']);
      expect(c.assignOverrideReasons['w-busy'], 'Covering leave');
    });

    test('travel validateTravelDraft reports sum mismatch', () async {
      final c = build();
      await c.retryHydrate();
      c.draft.value = c.draft.value.copyWith(participantIds: ['c1', 'c2']);
      c.setTravelLabourMinutes('60');
      c.setTravelMode(TravelApportionmentMode.explicit);
      c.setTravelExplicitShare('c1', '20');
      c.setTravelExplicitShare('c2', '30');
      expect(c.validateTravelDraft(), contains('sum'));
    });
  });
}
