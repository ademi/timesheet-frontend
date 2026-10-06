import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/rostering/domain/support_segment_editor.dart';
import 'package:rostiq/features/rostering/presentation/shared/assign_context_labels.dart';
import 'package:rostiq/features/rostering/data/composer_models.dart';
import 'package:rostiq/features/shifts/data/models/shift_models.dart';

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
      String? participantId,
    }) {
      return SupportSegmentRowDraft(
        shiftParticipantId: sp,
        participantId: participantId,
        anchorSupportItemCode: code,
        kind: kind,
        startAt: start ?? visitStart,
        endAt: end ?? visitEnd,
      );
    }

    test('accepts multi-row covering all participants', () {
      final err = validateSupportSegmentRows(
        rows: [
          row(sp: 'sp1', end: DateTime(2026, 10, 6, 12)),
          row(sp: 'sp2', start: DateTime(2026, 10, 6, 12), kind: 'shadow'),
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
        rows: [row(end: DateTime(2026, 10, 6, 16))],
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

    test('allows sleepover overlapping shadow when sleepover is valid', () {
      final nightStart = DateTime(2026, 10, 6, 22);
      final nightEnd = DateTime(2026, 10, 7, 6);
      final err = validateSupportSegmentRows(
        rows: [
          row(kind: 'sleepover', start: nightStart, end: nightEnd),
          row(kind: 'shadow', start: nightStart, end: nightEnd),
        ],
        visitStart: nightStart,
        visitEnd: nightEnd,
        activeShiftParticipantIds: {'sp1'},
      );
      expect(err, isNull);
    });

    test('rejects short same-day sleepover via kind rules', () {
      final err = validateSupportSegmentRows(
        rows: [row(kind: 'sleepover')],
        visitStart: visitStart,
        visitEnd: visitEnd,
        activeShiftParticipantIds: {'sp1'},
      );
      expect(err, contains('at least 8 hours'));
    });

    test('draft mode validates participantId without live coverage', () {
      final err = validateSupportSegmentRows(
        rows: [
          row(
            participantId: 'c1',
            end: DateTime(2026, 10, 6, 12),
          ),
          row(
            participantId: 'c1',
            start: DateTime(2026, 10, 6, 12),
            code: '01_015_0107_1_1',
          ),
        ],
        visitStart: visitStart,
        visitEnd: visitEnd,
        draftParticipantIds: {'c1', 'c2'},
        useParticipantId: true,
        requireCoverage: false,
      );
      expect(err, isNull);
    });
  });

  group('kind rules', () {
    test('sleepover under 8 hours is rejected', () {
      final row = SupportSegmentRowDraft(
        shiftParticipantId: 'sp1',
        anchorSupportItemCode: '01_010_0107_1_1',
        kind: 'sleepover',
        startAt: DateTime(2026, 10, 6, 22),
        endAt: DateTime(2026, 10, 7, 4),
      );
      expect(
        validateSupportSegmentKindRules(row, 0),
        contains('at least 8 hours'),
      );
    });

    test('sleepover that does not cross midnight is rejected', () {
      final row = SupportSegmentRowDraft(
        shiftParticipantId: 'sp1',
        anchorSupportItemCode: '01_010_0107_1_1',
        kind: 'sleepover',
        startAt: DateTime(2026, 10, 6, 8),
        endAt: DateTime(2026, 10, 6, 18),
      );
      expect(
        validateSupportSegmentKindRules(row, 0),
        contains('cross midnight'),
      );
    });

    test('valid overnight sleepover passes kind rules', () {
      final row = SupportSegmentRowDraft(
        shiftParticipantId: 'sp1',
        anchorSupportItemCode: '01_010_0107_1_1',
        kind: 'sleepover',
        startAt: DateTime(2026, 10, 6, 22),
        endAt: DateTime(2026, 10, 7, 6),
      );
      expect(validateSupportSegmentKindRules(row, 0), isNull);
    });

    test('shadow helper copy is set', () {
      expect(supportSegmentKindHelper('shadow'), contains('6 weekday hours'));
      expect(supportSegmentKindHelper('irregular_sil'), contains('SIL'));
      expect(supportSegmentKindHelper('direct'), isNull);
    });

    test('long shadow emits soft warning', () {
      final warnings = supportSegmentKindWarnings([
        SupportSegmentRowDraft(
          shiftParticipantId: 'sp1',
          anchorSupportItemCode: '01_011_0107_1_1',
          kind: 'shadow',
          startAt: DateTime(2026, 10, 6, 9),
          endAt: DateTime(2026, 10, 6, 14),
        ),
      ]);
      expect(warnings, isNotEmpty);
      expect(warnings.first, contains('standing double-up'));
    });
  });

  group('offset clock mapping', () {
    final windowStart = DateTime(2026, 10, 6, 9);

    test('round-trips offsets', () {
      final start = DateTime(2026, 10, 6, 10);
      final end = DateTime(2026, 10, 6, 12);
      final offsets = segmentOffsetsFromWindow(
        windowStart: windowStart,
        startAt: start,
        endAt: end,
      );
      expect(offsets.offsetStartMinutes, 60);
      expect(offsets.offsetEndMinutes, 180);

      final back = segmentWindowFromOffsets(
        windowStart: windowStart,
        offsetStartMinutes: offsets.offsetStartMinutes,
        offsetEndMinutes: offsets.offsetEndMinutes,
      );
      expect(back.startAt, start);
      expect(back.endAt, end);
    });

    test('resolveSegmentEndAt bumps overnight end', () {
      final start = DateTime(2026, 10, 6, 22);
      final end = resolveSegmentEndAt(
        startAt: start,
        endHour: 6,
        endMinute: 0,
        visitEnd: DateTime(2026, 10, 7, 8),
      );
      expect(end, DateTime(2026, 10, 7, 6));
      expect(supportSegmentCrossesMidnight(start, end), isTrue);
    });

    test('template ↔ rows mapping preserves kind and offsets', () {
      final rows = [
        SupportSegmentRowDraft(
          shiftParticipantId: '',
          participantId: 'c1',
          anchorSupportItemCode: '01_011_0107_1_1',
          kind: 'shadow',
          startAt: DateTime(2026, 10, 6, 9),
          endAt: DateTime(2026, 10, 6, 11),
        ),
        SupportSegmentRowDraft(
          shiftParticipantId: '',
          participantId: 'c1',
          anchorSupportItemCode: '01_015_0107_1_1',
          kind: 'direct',
          startAt: DateTime(2026, 10, 6, 11),
          endAt: DateTime(2026, 10, 6, 15),
        ),
      ];
      final template = segmentTemplateFromRows(
        rows: rows,
        windowStart: windowStart,
      );
      expect(template, hasLength(2));
      expect(template[0].kind, 'shadow');
      expect(template[0].offsetStartMinutes, 0);
      expect(template[0].offsetEndMinutes, 120);
      expect(template[1].offsetStartMinutes, 120);
      expect(template[1].offsetEndMinutes, 360);

      final hydrated = supportSegmentRowsFromTemplate(
        template: template,
        windowStart: windowStart,
      );
      expect(hydrated[0].kind, 'shadow');
      expect(hydrated[0].participantId, 'c1');
      expect(hydrated[1].startAt, DateTime(2026, 10, 6, 11));
    });

    test('seedDraftSegmentRows creates one full-window direct per person', () {
      final seeded = seedDraftSegmentRows(
        windowStart: DateTime(2026, 10, 6, 9),
        windowEnd: DateTime(2026, 10, 6, 15),
        participantIds: const ['c1', 'c2'],
        supportItemCode: '01_011_0107_1_1',
      );
      expect(seeded, hasLength(2));
      expect(seeded.every((r) => r.kind == 'direct'), isTrue);
      expect(seeded.map((r) => r.participantId), ['c1', 'c2']);
    });

    test('expandTemplateRowsForLiveEditor maps participant → SP and keeps kind', () {
      final template = [
        const SegmentTemplateItem(
          participantId: 'c1',
          anchorSupportItemCode: '01_011_0107_1_1',
          kind: 'shadow',
          offsetStartMinutes: 0,
          offsetEndMinutes: 60,
        ),
        const SegmentTemplateItem(
          participantId: 'c2',
          anchorSupportItemCode: '01_015_0107_1_1',
          kind: 'irregular_sil',
          offsetStartMinutes: 60,
          offsetEndMinutes: 180,
        ),
        const SegmentTemplateItem(
          participantId: 'missing',
          anchorSupportItemCode: '01_011_0107_1_1',
          offsetStartMinutes: 0,
          offsetEndMinutes: 30,
        ),
      ];
      final rows = expandTemplateRowsForLiveEditor(
        template: template,
        windowStart: windowStart,
        participantIdToShiftParticipantId: const {'c1': 'sp1', 'c2': 'sp2'},
      );
      expect(rows, hasLength(2));
      expect(rows[0].shiftParticipantId, 'sp1');
      expect(rows[0].kind, 'shadow');
      expect(rows[0].endAt, DateTime(2026, 10, 6, 10));
      expect(rows[1].kind, 'irregular_sil');
      expect(rows[1].participantId, 'c2');
    });

    test('segmentTemplateFromLiveWindows dual-write preserves kinds', () {
      final template = segmentTemplateFromLiveWindows(
        windowStart: windowStart,
        segments: [
          LiveSegmentWindow(
            shiftParticipantId: 'sp1',
            anchorSupportItemCode: '01_011_0107_1_1',
            kind: 'sleepover',
            startAt: DateTime(2026, 10, 6, 22),
            endAt: DateTime(2026, 10, 7, 6),
          ),
          LiveSegmentWindow(
            shiftParticipantId: 'sp1',
            anchorSupportItemCode: '01_011_0107_1_1',
            kind: 'shadow',
            startAt: DateTime(2026, 10, 6, 22),
            endAt: DateTime(2026, 10, 7, 6),
          ),
        ],
        participantIdForShiftParticipant: (sp) => sp == 'sp1' ? 'c1' : null,
      );
      expect(template, hasLength(2));
      expect(template[0].kind, 'sleepover');
      expect(template[0].participantId, 'c1');
      expect(template[0].offsetStartMinutes, 13 * 60); // 09:00 → 22:00
      expect(template[1].kind, 'shadow');
    });
  });

  group('phase 3 coverage and dual-worker', () {
    test('empty template has no coverage error (Mode A)', () {
      expect(
        draftSegmentTemplateCoverageError(
          template: const [],
          participantIds: const ['c1', 'c2'],
        ),
        isNull,
      );
    });

    test('non-empty template missing a participant fails', () {
      final err = draftSegmentTemplateCoverageError(
        template: const [
          SegmentTemplateItem(
            participantId: 'c1',
            anchorSupportItemCode: '01_011_0107_1_1',
            offsetStartMinutes: 0,
            offsetEndMinutes: 60,
          ),
        ],
        participantIds: const ['c1', 'c2'],
      );
      expect(err, contains('Every participant'));
      expect(err, contains('Mode A'));
    });

    test('full coverage passes', () {
      expect(
        draftSegmentTemplateCoverageError(
          template: const [
            SegmentTemplateItem(
              participantId: 'c1',
              anchorSupportItemCode: '01_011_0107_1_1',
              offsetStartMinutes: 0,
              offsetEndMinutes: 60,
            ),
            SegmentTemplateItem(
              participantId: 'c2',
              anchorSupportItemCode: '01_011_0107_1_1',
              offsetStartMinutes: 0,
              offsetEndMinutes: 60,
            ),
          ],
          participantIds: const ['c1', 'c2'],
        ),
        isNull,
      );
    });

    test('dual-worker hint when ≥2 workers and no shadow', () {
      expect(
        shouldShowDualWorkerHint(workerCount: 2, rowKinds: const ['direct']),
        isTrue,
      );
      expect(
        shouldShowDualWorkerHint(
          workerCount: 2,
          rowKinds: const ['direct', 'shadow'],
        ),
        isFalse,
      );
      expect(
        shouldShowDualWorkerHint(workerCount: 1, rowKinds: const ['direct']),
        isFalse,
      );
    });

    test('fullWindowDirectTemplateItem spans the window', () {
      final item = fullWindowDirectTemplateItem(
        participantId: 'c3',
        anchorSupportItemCode: '01_011_0107_1_1',
        windowStart: DateTime(2026, 10, 6, 9),
        windowEnd: DateTime(2026, 10, 6, 15),
        sortOrder: 2,
        groupSize: 3,
      );
      expect(item.participantId, 'c3');
      expect(item.kind, 'direct');
      expect(item.offsetStartMinutes, 0);
      expect(item.offsetEndMinutes, 360);
      expect(item.groupSize, 3);
      expect(item.sortOrder, 2);
    });

    test('draft requireCoverage rejects missing participant', () {
      final visitStart = DateTime(2026, 10, 6, 9);
      final visitEnd = DateTime(2026, 10, 6, 15);
      final err = validateSupportSegmentRows(
        rows: [
          SupportSegmentRowDraft(
            shiftParticipantId: '',
            participantId: 'c1',
            anchorSupportItemCode: '01_011_0107_1_1',
            startAt: visitStart,
            endAt: visitEnd,
          ),
        ],
        visitStart: visitStart,
        visitEnd: visitEnd,
        draftParticipantIds: {'c1', 'c2'},
        useParticipantId: true,
        requireCoverage: true,
      );
      expect(err, contains('Every participant'));
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
