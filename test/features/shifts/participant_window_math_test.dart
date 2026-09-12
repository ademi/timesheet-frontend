import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/shifts/utils/participant_window_math.dart';

void main() {
  final shiftStart = DateTime.utc(2026, 9, 12, 10);
  final shiftEnd = DateTime.utc(2026, 9, 12, 14);

  group('validateParticipantWindows', () {
    test('accepts single full-shift window', () {
      expect(
        validateParticipantWindows(
          defaultFullShiftWindows(shiftStart, shiftEnd),
          shiftStart: shiftStart,
          shiftEnd: shiftEnd,
        ),
        isNull,
      );
    });

    test('rejects empty windows', () {
      expect(
        validateParticipantWindows(
          const [],
          shiftStart: shiftStart,
          shiftEnd: shiftEnd,
        ),
        'Add at least one time window',
      );
    });

    test('rejects end before or equal start', () {
      expect(
        validateParticipantWindows(
          [
            ParticipantWindowDraft(start: shiftStart, end: shiftStart),
          ],
          shiftStart: shiftStart,
          shiftEnd: shiftEnd,
        ),
        'End must be after start',
      );
    });

    test('rejects window past shift end', () {
      expect(
        validateParticipantWindows(
          [
            ParticipantWindowDraft(
              start: shiftStart,
              end: shiftEnd.add(const Duration(minutes: 30)),
            ),
          ],
          shiftStart: shiftStart,
          shiftEnd: shiftEnd,
        ),
        contains('after shift end'),
      );
    });

    test('rejects window before shift start', () {
      expect(
        validateParticipantWindows(
          [
            ParticipantWindowDraft(
              start: shiftStart.subtract(const Duration(minutes: 15)),
              end: shiftEnd,
            ),
          ],
          shiftStart: shiftStart,
          shiftEnd: shiftEnd,
        ),
        contains('before shift start'),
      );
    });

    test('rejects overlapping windows', () {
      expect(
        validateParticipantWindows(
          [
            ParticipantWindowDraft(
              start: shiftStart,
              end: DateTime.utc(2026, 9, 12, 12),
            ),
            ParticipantWindowDraft(
              start: DateTime.utc(2026, 9, 12, 11, 30),
              end: shiftEnd,
            ),
          ],
          shiftStart: shiftStart,
          shiftEnd: shiftEnd,
        ),
        'Time windows must not overlap',
      );
    });

    test('allows contiguous non-overlapping windows', () {
      expect(
        validateParticipantWindows(
          [
            ParticipantWindowDraft(
              start: shiftStart,
              end: DateTime.utc(2026, 9, 12, 12),
            ),
            ParticipantWindowDraft(
              start: DateTime.utc(2026, 9, 12, 12),
              end: shiftEnd,
            ),
          ],
          shiftStart: shiftStart,
          shiftEnd: shiftEnd,
        ),
        isNull,
      );
    });
  });

  test('formatWindowsSummary joins ranges', () {
    expect(
      formatWindowsSummary([
        ParticipantWindowDraft(
          start: DateTime.utc(2026, 9, 12, 10),
          end: DateTime.utc(2026, 9, 12, 12),
        ),
        ParticipantWindowDraft(
          start: DateTime.utc(2026, 9, 12, 12, 30),
          end: DateTime.utc(2026, 9, 12, 14),
        ),
      ]),
      contains('·'),
    );
  });
}
