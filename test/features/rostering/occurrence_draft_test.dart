import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/rostering/domain/composer_validation.dart';
import 'package:rostiq/features/rostering/domain/occurrence_draft.dart';
import 'package:rostiq/features/shifts/data/models/shift_models.dart';

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
  });

  group('ComposerValidation', () {
    test('requires place for save', () {
      final draft = OccurrenceDraft.group(
        jobId: 'job-1',
        participantIds: const ['p1'],
      );

      final errors = ComposerValidation.validate(draft);

      expect(errors, contains(ComposerValidation.placeRequired));
    });

    test('accepts branch / site / labelled place', () {
      expect(
        ComposerValidation.validate(
          OccurrenceDraft.group(
            jobId: 'job-1',
            participantIds: const ['p1'],
            place: const DraftPlace.branch('branch-1'),
          ),
        ),
        isEmpty,
      );
      expect(
        ComposerValidation.validate(
          OccurrenceDraft.oneSession(
            clientId: 'c1',
            place: const DraftPlace.clientSite('site-1'),
          ),
        ),
        isEmpty,
      );
      expect(
        ComposerValidation.validate(
          OccurrenceDraft.group(
            jobId: 'job-1',
            participantIds: const ['p1'],
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

    test('rejects more than 32 participants', () {
      final ids = List.generate(33, (i) => 'p$i');
      final draft = OccurrenceDraft.group(
        jobId: 'job-1',
        participantIds: ids,
        place: const DraftPlace.branch('b1'),
      );

      expect(
        ComposerValidation.validate(draft),
        contains(ComposerValidation.participantsCap),
      );
    });

    test('publish requires support anchor when no auto-seed', () {
      final draft = OccurrenceDraft.group(
        jobId: 'job-1',
        participantIds: const ['p1'],
        place: const DraftPlace.branch('b1'),
      );

      final errors = ComposerValidation.validate(
        draft,
        forPublish: true,
        hasAutoSeedSupport: false,
      );

      expect(errors, contains(ComposerValidation.supportAnchorRequired));
    });

    test('publish skips support anchor when auto-seed available', () {
      final draft = OccurrenceDraft.oneSession(
        clientId: 'c1',
        place: const DraftPlace.clientSite('site-1'),
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
      final withItem = OccurrenceDraft.group(
        jobId: 'job-1',
        participantIds: const ['p1'],
        place: const DraftPlace.branch('b1'),
        supportItemCode: '01_011_0107_1_1',
      );
      final withSegment = OccurrenceDraft.group(
        jobId: 'job-1',
        participantIds: const ['p1'],
        place: const DraftPlace.branch('b1'),
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
