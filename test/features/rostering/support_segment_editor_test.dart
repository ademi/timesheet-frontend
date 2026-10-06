import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/rostering/domain/support_segment_editor.dart';
import 'package:rostiq/features/rostering/presentation/shared/assign_context_labels.dart';
import 'package:rostiq/features/rostering/data/composer_models.dart';

void main() {
  group('validateSupportSegmentRows', () {
    final visitStart = DateTime(2026, 10, 6, 9);
    final visitEnd = DateTime(2026, 10, 6, 15);

    SupportSegmentRowDraft row({
      String sp = 'sp1',
      String code = '01_011_0107_1_1',
      String kind = 'direct',
      DateTime? start,
      DateTime? end,
    }) {
      return SupportSegmentRowDraft(
        shiftParticipantId: sp,
        anchorSupportItemCode: code,
        kind: kind,
        startAt: start ?? visitStart,
        endAt: end ?? visitEnd,
      );
    }

    test('accepts multi-row covering all participants', () {
      final err = validateSupportSegmentRows(
        rows: [
          row(
            sp: 'sp1',
            end: DateTime(2026, 10, 6, 12),
          ),
          row(
            sp: 'sp2',
            start: DateTime(2026, 10, 6, 12),
            kind: 'shadow',
          ),
        ],
        visitStart: visitStart,
        visitEnd: visitEnd,
        activeShiftParticipantIds: {'sp1', 'sp2'},
      );
      expect(err, isNull);
    });

    test('rejects overlap of direct segments on same participant', () {
      final err = validateSupportSegmentRows(
        rows: [
          row(end: DateTime(2026, 10, 6, 13)),
          row(start: DateTime(2026, 10, 6, 12)),
        ],
        visitStart: visitStart,
        visitEnd: visitEnd,
        activeShiftParticipantIds: {'sp1'},
      );
      expect(err, contains('overlap'));
    });

    test('rejects segment outside visit window', () {
      final err = validateSupportSegmentRows(
        rows: [
          row(end: DateTime(2026, 10, 6, 16)),
        ],
        visitStart: visitStart,
        visitEnd: visitEnd,
        activeShiftParticipantIds: {'sp1'},
      );
      expect(err, contains('inside the visit window'));
    });

    test('rejects missing participant coverage', () {
      final err = validateSupportSegmentRows(
        rows: [row(sp: 'sp1')],
        visitStart: visitStart,
        visitEnd: visitEnd,
        activeShiftParticipantIds: {'sp1', 'sp2'},
      );
      expect(err, contains('Every active participant'));
    });

    test('allows sleepover overlapping shadow', () {
      final err = validateSupportSegmentRows(
        rows: [
          row(kind: 'sleepover'),
          row(kind: 'shadow'),
        ],
        visitStart: visitStart,
        visitEnd: visitEnd,
        activeShiftParticipantIds: {'sp1'},
      );
      expect(err, isNull);
    });
  });

  group('clientConflictChipLabel', () {
    test('maps visit and shift kinds', () {
      expect(
        clientConflictChipLabel(
          ClientConflictOut(
            id: 'v1',
            kind: 'visit',
            scheduledStart: DateTime.utc(2026, 10, 6, 9),
            scheduledEnd: DateTime.utc(2026, 10, 6, 10),
          ),
        ),
        'Overlapping visit…',
      );
      expect(
        clientConflictChipLabel(
          ClientConflictOut(
            id: 's1',
            kind: 'shift',
            scheduledStart: DateTime.utc(2026, 10, 6, 9),
            scheduledEnd: DateTime.utc(2026, 10, 6, 10),
          ),
        ),
        'Open shift hole…',
      );
    });
  });
}
