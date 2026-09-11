import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/shifts/utils/group_participant_draft.dart';

void main() {
  group('GroupParticipantDraftSet', () {
    test('validate requires at least one participant', () {
      final draft = GroupParticipantDraftSet(equalSplit: true);
      expect(draft.validate(), isNotNull);
    });

    test('validate allows equal split without manual sum check', () {
      final draft = GroupParticipantDraftSet(
        participants: const [
          GroupParticipantDraft(
            participantId: 'c1',
            displayName: 'Maya Smith',
            allocationValue: 0,
          ),
        ],
        equalSplit: true,
      );
      expect(draft.validate(), isNull);
    });

    test('validate requires sum 100 when not equal split', () {
      final under = GroupParticipantDraftSet(
        participants: const [
          GroupParticipantDraft(
            participantId: 'c1',
            displayName: 'Maya',
            allocationValue: 40,
          ),
          GroupParticipantDraft(
            participantId: 'c2',
            displayName: 'Jordan',
            allocationValue: 40,
          ),
        ],
        equalSplit: false,
      );
      expect(under.validate(), isNotNull);

      final ok = under.copyWith(
        participants: const [
          GroupParticipantDraft(
            participantId: 'c1',
            displayName: 'Maya',
            allocationValue: 60,
          ),
          GroupParticipantDraft(
            participantId: 'c2',
            displayName: 'Jordan',
            allocationValue: 40,
          ),
        ],
      );
      expect(ok.validate(), isNull);
    });

    test('validate blocks N > 32', () {
      final participants = List.generate(
        33,
        (i) => GroupParticipantDraft(
          participantId: 'c$i',
          displayName: 'Person $i',
          allocationValue: 0,
        ),
      );
      final draft = GroupParticipantDraftSet(
        participants: participants,
        equalSplit: true,
      );
      expect(draft.validate(), isNotNull);
    });

    test('add appends and recomputes equal split when enabled', () {
      var draft = GroupParticipantDraftSet(equalSplit: true)
          .add(
            const GroupParticipantDraft(
              participantId: 'c1',
              displayName: 'Maya',
              allocationValue: 0,
            ),
          )
          .add(
            const GroupParticipantDraft(
              participantId: 'c2',
              displayName: 'Jordan',
              allocationValue: 0,
            ),
          );

      expect(draft.participants.map((p) => p.allocationValue), [50.0, 50.0]);

      draft = draft.add(
        const GroupParticipantDraft(
          participantId: 'c3',
          displayName: 'Alex',
          allocationValue: 0,
          isHostIncluded: true,
        ),
      );
      expect(draft.participants.map((p) => p.allocationValue), [
        33.34,
        33.33,
        33.33,
      ]);
      expect(draft.participants.last.isHostIncluded, isTrue);
    });

    test('add does not overwrite manual values when equalSplit is false', () {
      final draft = GroupParticipantDraftSet(
        equalSplit: false,
        participants: const [
          GroupParticipantDraft(
            participantId: 'c1',
            displayName: 'Maya',
            allocationValue: 70,
          ),
        ],
      ).add(
        const GroupParticipantDraft(
          participantId: 'c2',
          displayName: 'Jordan',
          allocationValue: 30,
        ),
      );

      expect(draft.participants.map((p) => p.allocationValue), [70.0, 30.0]);
    });

    test('remove drops participant and recomputes equal split', () {
      final draft = GroupParticipantDraftSet(equalSplit: true)
          .add(
            const GroupParticipantDraft(
              participantId: 'c1',
              displayName: 'Maya',
              allocationValue: 0,
            ),
          )
          .add(
            const GroupParticipantDraft(
              participantId: 'c2',
              displayName: 'Jordan',
              allocationValue: 0,
            ),
          )
          .add(
            const GroupParticipantDraft(
              participantId: 'c3',
              displayName: 'Alex',
              allocationValue: 0,
            ),
          )
          .remove('c2');

      expect(draft.participants.map((p) => p.participantId), ['c1', 'c3']);
      expect(draft.participants.map((p) => p.allocationValue), [50.0, 50.0]);
    });

    test('recomputeEqualSplit updates values and enables equalSplit', () {
      final draft = GroupParticipantDraftSet(
        equalSplit: false,
        participants: const [
          GroupParticipantDraft(
            participantId: 'c1',
            displayName: 'Maya',
            allocationValue: 70,
          ),
          GroupParticipantDraft(
            participantId: 'c2',
            displayName: 'Jordan',
            allocationValue: 30,
          ),
        ],
      ).recomputeEqualSplit();

      expect(draft.equalSplit, isTrue);
      expect(draft.participants.map((p) => p.allocationValue), [50.0, 50.0]);
    });
  });
}
