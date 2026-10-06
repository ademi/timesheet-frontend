import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/rostering/domain/composer_steps.dart';
import 'package:rostiq/features/rostering/domain/composer_validation.dart';
import 'package:rostiq/features/rostering/domain/occurrence_draft.dart';
import 'package:rostiq/features/shifts/data/models/shift_models.dart';

OccurrenceDraft _scheduled({
  List<String> participantIds = const ['p1'],
  DraftPlace? place,
  String? supportItemCode,
}) {
  return OccurrenceDraft.group(
    jobId: 'job-1',
    participantIds: participantIds,
    place: place,
    supportItemCode: supportItemCode,
    scheduledStart: DateTime(2026, 10, 6, 9),
    scheduledEnd: DateTime(2026, 10, 6, 12),
  );
}

void main() {
  group('OccurrenceDraft preset visibility', () {
    test('one_session hides allocation and forces N=1', () {
      final draft = OccurrenceDraft.oneSession(clientId: 'client-1');

      expect(draft.preset, ComposerPreset.oneSession);
      expect(draft.showsAllocation, isFalse);
      expect(draft.showsWorkerCount, isFalse);
      expect(draft.participantIds, ['client-1']);
      expect(draft.equalSplit, isTrue);
    });

    test('group shows allocation and worker_count', () {
      final draft = OccurrenceDraft.group(
        jobId: 'job-1',
        participantIds: const ['p1', 'p2'],
      );

      expect(draft.preset, ComposerPreset.group);
      expect(draft.showsAllocation, isTrue);
      expect(draft.showsWorkerCount, isTrue);
      expect(draft.participantIds, ['p1', 'p2']);
    });

    test('copyWith can switch preset visibility', () {
      final one = OccurrenceDraft.oneSession(clientId: 'c1');
      final group = one.copyWith(
        preset: ComposerPreset.group,
        participantIds: const ['c1', 'c2'],
        workerCount: 2,
      );

      expect(group.showsAllocation, isTrue);
      expect(group.showsWorkerCount, isTrue);
      expect(group.workerCount, 2);
    });

    test('clearJobId drops standing/program binding', () {
      final draft = OccurrenceDraft.oneSession(clientId: 'c1').copyWith(
        jobId: 'standing-1',
      );
      final cleared = draft.copyWith(
        preset: ComposerPreset.group,
        clearJobId: true,
      );
      expect(cleared.jobId, isNull);
      expect(cleared.preset, ComposerPreset.group);
    });
  });

  group('ComposerValidation', () {
    test('requires place for save', () {
      final errors = ComposerValidation.validate(_scheduled());

      expect(errors, contains(ComposerValidation.placeRequired));
    });

    test('accepts branch / site / labelled place', () {
      expect(
        ComposerValidation.validate(
          _scheduled(place: const DraftPlace.branch('branch-1')),
        ),
        isEmpty,
      );
      expect(
        ComposerValidation.validate(
          OccurrenceDraft.oneSession(
            clientId: 'c1',
            place: const DraftPlace.clientSite('site-1'),
            scheduledStart: DateTime(2026, 10, 6, 9),
            scheduledEnd: DateTime(2026, 10, 6, 12),
          ),
        ),
        isEmpty,
      );
      expect(
        ComposerValidation.validate(
          _scheduled(
            place: const DraftPlace.labelled(
              label: 'Park',
              latitude: -33.8,
              longitude: 151.2,
              postalCode: '2000',
            ),
          ),
        ),
        isEmpty,
      );
    });

    test('rejects labelled place without postal code', () {
      final draft = _scheduled(
        place: const DraftPlace.labelled(
          label: 'Park',
          latitude: -33.8,
          longitude: 151.2,
          postalCode: '',
        ),
      );
      expect(
        ComposerValidation.validate(draft),
        contains(ComposerValidation.postalCodeRequired),
      );
      expect(
        ComposerValidation.validateStep(ComposerStep.place, draft),
        contains(ComposerValidation.postalCodeRequired),
      );
    });

    test('rejects more than 32 participants', () {
      final ids = List.generate(33, (i) => 'p$i');
      final draft = _scheduled(
        participantIds: ids,
        place: const DraftPlace.branch('b1'),
      );

      expect(
        ComposerValidation.validate(draft),
        contains(ComposerValidation.participantsCap),
      );
    });

    test('publish requires support anchor when no auto-seed', () {
      final draft = _scheduled(place: const DraftPlace.branch('b1'));

      final errors = ComposerValidation.validate(
        draft,
        forPublish: true,
        hasAutoSeedSupport: false,
      );

      expect(errors, contains(ComposerValidation.supportAnchorRequired));
    });

    test('step gates: clients then when then place', () {
      final empty = OccurrenceDraft.group(jobId: 'job-1');
      expect(
        ComposerValidation.validateStep(ComposerStep.clients, empty),
        contains(ComposerValidation.participantsRequired),
      );

      final withClient = _scheduled();
      expect(
        ComposerValidation.validateStep(ComposerStep.clients, withClient),
        isEmpty,
      );
      expect(
        ComposerValidation.validateStep(ComposerStep.when, withClient),
        isEmpty,
      );
      expect(
        ComposerValidation.validateStep(ComposerStep.place, withClient),
        contains(ComposerValidation.placeRequired),
      );
    });

    test('one session rejects multiple clients at clients step', () {
      final draft = OccurrenceDraft.oneSession(clientId: 'c1').copyWith(
        participantIds: const ['c1', 'c2'],
      );
      expect(
        ComposerValidation.validateStep(ComposerStep.clients, draft),
        contains(ComposerValidation.oneSessionSingleClient),
      );
    });

    test('place step gates travel explicit sum', () {
      final draft = _scheduled(place: const DraftPlace.branch('b1'));
      expect(
        ComposerValidation.validateStep(
          ComposerStep.place,
          draft,
          travelError: 'Share minutes must sum to travel minutes',
        ),
        contains('Share minutes must sum to travel minutes'),
      );
    });

    test('support step requires anchor', () {
      final draft = _scheduled(place: const DraftPlace.branch('b1'));
      expect(
        ComposerValidation.validateStep(ComposerStep.support, draft),
        contains(ComposerValidation.supportAnchorStep),
      );
    });

    test('support step requires segment template coverage when planned', () {
      final draft = OccurrenceDraft.group(
        participantIds: const ['c1', 'c2'],
        place: const DraftPlace.branch('b1'),
        scheduledStart: DateTime(2026, 10, 6, 9),
        scheduledEnd: DateTime(2026, 10, 6, 12),
        supportItemCode: '01_011_0107_1_1',
        segmentTemplate: const [
          SegmentTemplateItem(
            participantId: 'c1',
            anchorSupportItemCode: '01_011_0107_1_1',
            offsetStartMinutes: 0,
            offsetEndMinutes: 60,
          ),
        ],
      );
      expect(
        ComposerValidation.validateStep(ComposerStep.support, draft).first,
        contains('Every participant'),
      );
      expect(
        ComposerValidation.validate(draft, forPublish: true).any(
          (e) => e.contains('Every participant'),
        ),
        isTrue,
      );
      // Save draft (not publish) does not block on incomplete template.
      expect(
        ComposerValidation.validate(draft).any(
          (e) => e.contains('Every participant'),
        ),
        isFalse,
      );
    });

    test('clients step gates custom allocation sum', () {
      final draft = OccurrenceDraft.group(
        participantIds: const ['c1', 'c2'],
        equalSplit: false,
      );
      expect(
        ComposerValidation.validateStep(
          ComposerStep.clients,
          draft,
          allocationError: ComposerValidation.allocationSum,
        ),
        contains(ComposerValidation.allocationSum),
      );
      expect(
        ComposerValidation.validateCustomAllocation(
          draft: draft,
          percentByParticipant: const {'c1': 40, 'c2': 60},
        ),
        isNull,
      );
      expect(
        ComposerValidation.validateCustomAllocation(
          draft: draft,
          percentByParticipant: const {'c1': 40, 'c2': 40},
        ),
        ComposerValidation.allocationSum,
      );
    });

    test('publish skips support anchor when auto-seed available', () {
      final draft = OccurrenceDraft.oneSession(
        clientId: 'c1',
        place: const DraftPlace.clientSite('site-1'),
        scheduledStart: DateTime(2026, 10, 6, 9),
        scheduledEnd: DateTime(2026, 10, 6, 12),
      );

      expect(
        ComposerValidation.validate(
          draft,
          forPublish: true,
          hasAutoSeedSupport: true,
        ),
        isEmpty,
      );
    });

    test('publish accepts supportItemCode or segment template as anchor', () {
      final withItem = _scheduled(
        place: const DraftPlace.branch('b1'),
        supportItemCode: '01_011_0107_1_1',
      );
      final withSegment = OccurrenceDraft.group(
        jobId: 'job-1',
        participantIds: const ['p1'],
        place: const DraftPlace.branch('b1'),
        scheduledStart: DateTime(2026, 10, 6, 9),
        scheduledEnd: DateTime(2026, 10, 6, 12),
        segmentTemplate: const [
          SegmentTemplateItem(
            participantId: 'p1',
            anchorSupportItemCode: '01_011_0107_1_1',
            offsetStartMinutes: 0,
            offsetEndMinutes: 60,
          ),
        ],
      );

      expect(
        ComposerValidation.validate(
          withItem,
          forPublish: true,
          hasAutoSeedSupport: false,
        ),
        isEmpty,
      );
      expect(
        ComposerValidation.validate(
          withSegment,
          forPublish: true,
          hasAutoSeedSupport: false,
        ),
        isEmpty,
      );
    });
  });
}
