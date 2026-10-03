import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/clients/data/models/client_models.dart';
import 'package:rostiq/features/jobs/utils/unified_support_args.dart';
import 'package:rostiq/features/rostering/domain/occurrence_draft.dart';
import 'package:rostiq/features/rostering/domain/roster_composer_args.dart';
import 'package:rostiq/features/shifts/data/models/shift_models.dart';
import 'package:rostiq/features/shifts/group_book/group_shift_book_args.dart';
import 'package:rostiq/features/shifts/group_book/group_shift_edit_controller.dart';

ClientOut _client(String id, {String name = 'Alex'}) => ClientOut(
  id: id,
  tenantId: 't1',
  fullName: name,
  status: 'active',
  metadata: const {},
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

ShiftOut _shift(String id) => ShiftOut(
  id: id,
  tenantId: 't1',
  jobId: 'job-1',
  jobTitle: 'Support',
  scheduledStart: DateTime.utc(2026, 10, 4, 9),
  scheduledEnd: DateTime.utc(2026, 10, 4, 12),
  requiredSlots: 1,
  openSlots: 1,
  status: 'draft',
  createdAt: DateTime.utc(2026, 10, 4),
  updatedAt: DateTime.utc(2026, 10, 4),
);

void main() {
  group('RosterComposerArgs.fromRaw', () {
    test('returns typed RosterComposerArgs unchanged', () {
      const args = RosterComposerArgs(
        clientId: 'c1',
        preset: ComposerPreset.oneSession,
      );
      expect(RosterComposerArgs.fromRaw(args), same(args));
    });

    test('maps UnifiedSupportArgs oneSession → one session preset', () {
      final client = _client('c1');
      final args = RosterComposerArgs.fromRaw(
        UnifiedSupportArgs.forClient(
          client,
          mode: UnifiedSupportMode.oneSession,
        ),
      );

      expect(args.clientId, 'c1');
      expect(args.client, same(client));
      expect(args.preset, ComposerPreset.oneSession);
      expect(args.repeatEnabled, isFalse);
    });

    test('maps UnifiedSupportArgs ongoing → one session + repeat', () {
      final args = RosterComposerArgs.fromRaw(
        UnifiedSupportArgs.forClient(
          _client('c2'),
          mode: UnifiedSupportMode.ongoing,
        ),
      );

      expect(args.clientId, 'c2');
      expect(args.preset, ComposerPreset.oneSession);
      expect(args.repeatEnabled, isTrue);
    });

    test('maps GroupShiftBookArgs → group preset + participant seed', () {
      final participant = _client('p1', name: 'Maya');
      final args = RosterComposerArgs.fromRaw(
        GroupShiftBookArgs(
          participantId: 'p1',
          participantName: 'Maya',
          participant: participant,
        ),
      );

      expect(args.preset, ComposerPreset.group);
      expect(args.participantId, 'p1');
      expect(args.participantName, 'Maya');
      expect(args.client, same(participant));
      expect(args.repeatEnabled, isFalse);
    });

    test('maps GroupShiftEditArgs → shiftId', () {
      final shift = _shift('shift-9');
      final args = RosterComposerArgs.fromRaw(GroupShiftEditArgs(shift: shift));

      expect(args.shiftId, 'shift-9');
      expect(args.shift, same(shift));
      expect(args.preset, ComposerPreset.group);
    });

    test('maps ClientOut → one session with client', () {
      final client = _client('c3');
      final args = RosterComposerArgs.fromRaw(client);

      expect(args.clientId, 'c3');
      expect(args.client, same(client));
      expect(args.preset, ComposerPreset.oneSession);
      expect(args.repeatEnabled, isTrue);
    });

    test('maps map from unified support keys', () {
      final args = RosterComposerArgs.fromRaw({
        'clientId': 'c4',
        'mode': 'oneSession',
      });

      expect(args.clientId, 'c4');
      expect(args.preset, ComposerPreset.oneSession);
      expect(args.repeatEnabled, isFalse);
    });

    test('maps map ongoing / recurrence keys', () {
      final ongoing = RosterComposerArgs.fromRaw({
        'client_id': 'c5',
        'mode': 'ongoing',
      });
      expect(ongoing.preset, ComposerPreset.oneSession);
      expect(ongoing.repeatEnabled, isTrue);

      final recurrence = RosterComposerArgs.fromRaw({
        'jobId': 'job-2',
        'repeat': true,
        'ruleId': 'rule-1',
      });
      expect(recurrence.jobId, 'job-2');
      expect(recurrence.repeatEnabled, isTrue);
      expect(recurrence.recurrenceRuleId, 'rule-1');
      expect(recurrence.preset, ComposerPreset.oneSession);
    });

    test('maps map group book keys', () {
      final args = RosterComposerArgs.fromRaw({
        'participantId': 'p9',
        'participant_name': 'Jordan',
        'preset': 'group',
      });

      expect(args.preset, ComposerPreset.group);
      expect(args.participantId, 'p9');
      expect(args.participantName, 'Jordan');
    });

    test('maps map with shiftId', () {
      final args = RosterComposerArgs.fromRaw({'shiftId': 'shift-3'});
      expect(args.shiftId, 'shift-3');
    });

    test('null / unknown → empty defaults', () {
      final args = RosterComposerArgs.fromRaw(null);
      expect(args.clientId, isNull);
      expect(args.shiftId, isNull);
      expect(args.preset, ComposerPreset.oneSession);
      expect(args.repeatEnabled, isFalse);
    });
  });
}
