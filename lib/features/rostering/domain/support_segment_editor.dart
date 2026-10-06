import '../../shifts/data/models/shift_models.dart';

/// Editable support-segment row (composer UI + client-side checks).
///
/// Post-assign rows use absolute [startAt]/[endAt].
/// Draft [segment_template] rows use the same clocks in UI, converted to
/// offset minutes from the visit/occurrence start via [segmentOffsetsFromWindow].
class SupportSegmentRowDraft {
  SupportSegmentRowDraft({
    required this.shiftParticipantId,
    required this.anchorSupportItemCode,
    required this.startAt,
    required this.endAt,
    this.anchorSupportItemName,
    this.kind = 'direct',
    /// Client / roster participant id for draft templates (not shift_participant).
    this.participantId,
  });

  String shiftParticipantId;
  String? participantId;
  String anchorSupportItemCode;
  String? anchorSupportItemName;
  String kind;
  DateTime startAt;
  DateTime endAt;
}

/// Backend [SegmentKind] values exposed in the composer.
const List<String> kSupportSegmentKinds = [
  'direct',
  'sleepover',
  'shadow',
  'irregular_sil',
];

/// Match BE max segments per visit / template.
const int kMaxSupportSegments = 32;

/// Soft warn when a shadow row looks like standing double-up (≥ this duration).
const Duration kShadowStandingDoubleUpWarnAfter = Duration(hours: 4);

String supportSegmentKindLabel(String kind) => switch (kind) {
  'sleepover' => 'Sleepover',
  'shadow' => 'Shadow',
  'irregular_sil' => 'Irregular SIL',
  _ => 'Direct',
};

/// Frozen Phase 0 helper copy under the kind control.
String? supportSegmentKindHelper(String kind) => switch (kind) {
  'sleepover' =>
    'Worker may sleep overnight. Must be continuous and at least 8 hours, '
        'and should cross midnight. Not an hourly night shift.',
  'shadow' =>
    'Introduce a new worker — not a standing double-up. Claimable shadow is '
        'capped at 6 weekday hours per participant per year.',
  'irregular_sil' =>
    'Unplanned support outside the regular SIL roster. Record why; agreement '
        'is needed before any claim.',
  _ => null,
};

const String kDraftSegmentsIntroCopy =
    'Planned support windows — applied when a worker is assigned.';

const String kDraftSegmentsModeACopy =
    'No planned windows yet — when a worker is assigned, one full-window '
    'Direct segment is created per participant unless you add rows here.';

/// Half-open overlap used by the segments service.
bool supportSegmentTimesOverlap(
  DateTime aStart,
  DateTime aEnd,
  DateTime bStart,
  DateTime bEnd,
) =>
    aStart.isBefore(bEnd) && bStart.isBefore(aEnd);

/// Mirrors backend `_kinds_conflict` on one visit × participant.
bool supportSegmentKindsConflict(String a, String b) {
  if (a == 'sleepover' && b == 'sleepover') return true;
  if (a == 'sleepover') return b == 'direct';
  if (b == 'sleepover') return a == 'direct';
  return true;
}

/// True when the interval crosses a local calendar midnight.
bool supportSegmentCrossesMidnight(DateTime start, DateTime end) {
  if (!end.isAfter(start)) return false;
  final startDay = DateTime(start.year, start.month, start.day);
  final endDay = DateTime(end.year, end.month, end.day);
  return endDay.isAfter(startDay);
}

/// Offset minutes from [windowStart] for a row's absolute window.
({int offsetStartMinutes, int offsetEndMinutes}) segmentOffsetsFromWindow({
  required DateTime windowStart,
  required DateTime startAt,
  required DateTime endAt,
}) {
  final startMins = startAt.difference(windowStart).inMinutes;
  final endMins = endAt.difference(windowStart).inMinutes;
  return (
    offsetStartMinutes: startMins < 0 ? 0 : startMins,
    offsetEndMinutes: endMins < 1 ? 1 : endMins,
  );
}

/// Absolute window from offset minutes relative to [windowStart].
({DateTime startAt, DateTime endAt}) segmentWindowFromOffsets({
  required DateTime windowStart,
  required int offsetStartMinutes,
  required int offsetEndMinutes,
}) {
  final start = windowStart.add(Duration(minutes: offsetStartMinutes));
  var end = windowStart.add(Duration(minutes: offsetEndMinutes));
  if (!end.isAfter(start)) {
    end = start.add(const Duration(minutes: 1));
  }
  return (startAt: start, endAt: end);
}

/// When the end clock is at/before start on the same civil day, bump end to the
/// next day (overnight / sleepover). Clamps to [visitEnd] if provided.
DateTime resolveSegmentEndAt({
  required DateTime startAt,
  required int endHour,
  required int endMinute,
  DateTime? visitEnd,
}) {
  var endAt = DateTime(
    startAt.year,
    startAt.month,
    startAt.day,
    endHour,
    endMinute,
  );
  if (!endAt.isAfter(startAt)) {
    endAt = endAt.add(const Duration(days: 1));
  }
  if (visitEnd != null && endAt.isAfter(visitEnd)) {
    endAt = visitEnd;
  }
  return endAt;
}

/// Kind-specific rostering rules (engines §4 / §6 / §8). Hard errors only.
String? validateSupportSegmentKindRules(SupportSegmentRowDraft row, int index) {
  final n = index + 1;
  if (row.kind != 'sleepover') return null;

  final duration = row.endAt.difference(row.startAt);
  if (duration < const Duration(hours: 8)) {
    return 'Segment $n sleepover must be at least 8 hours.';
  }
  if (!supportSegmentCrossesMidnight(row.startAt, row.endAt)) {
    return 'Segment $n sleepover should cross midnight.';
  }
  return null;
}

/// Soft, informational warnings (do not block save).
List<String> supportSegmentKindWarnings(List<SupportSegmentRowDraft> rows) {
  final out = <String>[];
  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    if (row.kind != 'shadow') continue;
    final duration = row.endAt.difference(row.startAt);
    if (duration >= kShadowStandingDoubleUpWarnAfter) {
      out.add(
        'Segment ${i + 1}: long shadow can look like a standing double-up — '
        'claimable shadow is capped at 6 weekday hours per participant per year.',
      );
    }
  }
  return out;
}

/// Client-side checks before PUT replace or draft template apply.
///
/// [activeShiftParticipantIds] — when non-empty, enforces live coverage (post-assign).
/// [requireParticipantCoverage] — draft templates use client participant ids;
///   pass draft participant ids and set [useParticipantId] true.
String? validateSupportSegmentRows({
  required List<SupportSegmentRowDraft> rows,
  required DateTime visitStart,
  required DateTime visitEnd,
  Set<String> activeShiftParticipantIds = const {},
  Set<String> draftParticipantIds = const {},
  bool useParticipantId = false,
  bool requireCoverage = true,
}) {
  if (rows.isEmpty) {
    return 'Add at least one segment before saving.';
  }
  if (rows.length > kMaxSupportSegments) {
    return 'At most $kMaxSupportSegments segments are allowed.';
  }

  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    final n = i + 1;
    final subjectId =
        useParticipantId
            ? (row.participantId ?? '').trim()
            : row.shiftParticipantId.trim();
    if (subjectId.isEmpty) {
      return useParticipantId
          ? 'Segment $n needs a participant.'
          : 'Segment $n needs a participant.';
    }
    if (row.anchorSupportItemCode.trim().isEmpty) {
      return 'Segment $n needs an NDIS support item.';
    }
    if (!row.endAt.isAfter(row.startAt)) {
      return 'Segment $n end must be after start.';
    }
    if (row.startAt.isBefore(visitStart) || row.endAt.isAfter(visitEnd)) {
      return 'Segment $n must sit inside the visit window.';
    }
    final kindErr = validateSupportSegmentKindRules(row, i);
    if (kindErr != null) return kindErr;
  }

  if (requireCoverage) {
    if (useParticipantId) {
      if (draftParticipantIds.isEmpty) {
        return 'Add at least one person before saving planned segments.';
      }
      final covered = <String>{
        for (final row in rows)
          if ((row.participantId ?? '').trim().isNotEmpty)
            row.participantId!.trim(),
      };
      if (draftParticipantIds.difference(covered).isNotEmpty) {
        return 'Every participant needs at least one planned segment.';
      }
      if (covered.difference(draftParticipantIds).isNotEmpty) {
        return 'A segment references a participant who is not on this draft.';
      }
    } else {
      if (activeShiftParticipantIds.isEmpty) {
        return 'No active participants on this shift.';
      }
      final covered = <String>{
        for (final row in rows) row.shiftParticipantId,
      };
      if (activeShiftParticipantIds.difference(covered).isNotEmpty) {
        return 'Every active participant needs at least one segment.';
      }
      if (covered.difference(activeShiftParticipantIds).isNotEmpty) {
        return 'A segment references a participant who is not on this shift.';
      }
    }
  }

  for (var i = 0; i < rows.length; i++) {
    for (var j = i + 1; j < rows.length; j++) {
      final a = rows[i];
      final b = rows[j];
      final aId =
          useParticipantId
              ? (a.participantId ?? '')
              : a.shiftParticipantId;
      final bId =
          useParticipantId
              ? (b.participantId ?? '')
              : b.shiftParticipantId;
      if (aId != bId) continue;
      if (!supportSegmentTimesOverlap(
        a.startAt,
        a.endAt,
        b.startAt,
        b.endAt,
      )) {
        continue;
      }
      if (supportSegmentKindsConflict(a.kind, b.kind)) {
        return 'Segments ${i + 1} and ${j + 1} overlap for the same participant.';
      }
    }
  }

  return null;
}

/// Hydrate UI rows from persisted draft [segment_template] offsets.
List<SupportSegmentRowDraft> supportSegmentRowsFromTemplate({
  required List<SegmentTemplateItem> template,
  required DateTime windowStart,
  String? defaultItemName,
}) {
  return [
    for (final s in template)
      () {
        final window = segmentWindowFromOffsets(
          windowStart: windowStart,
          offsetStartMinutes: s.offsetStartMinutes,
          offsetEndMinutes: s.offsetEndMinutes,
        );
        return SupportSegmentRowDraft(
          shiftParticipantId: '',
          participantId: s.participantId,
          anchorSupportItemCode: s.anchorSupportItemCode,
          anchorSupportItemName: defaultItemName,
          kind: s.kind,
          startAt: window.startAt,
          endAt: window.endAt,
        );
      }(),
  ];
}

/// Persist UI rows as draft [segment_template] offsets.
List<SegmentTemplateItem> segmentTemplateFromRows({
  required List<SupportSegmentRowDraft> rows,
  required DateTime windowStart,
}) {
  return [
    for (var i = 0; i < rows.length; i++)
      () {
        final row = rows[i];
        final offsets = segmentOffsetsFromWindow(
          windowStart: windowStart,
          startAt: row.startAt,
          endAt: row.endAt,
        );
        return SegmentTemplateItem(
          participantId: (row.participantId ?? '').trim(),
          anchorSupportItemCode: row.anchorSupportItemCode.trim(),
          kind: row.kind,
          offsetStartMinutes: offsets.offsetStartMinutes,
          offsetEndMinutes: offsets.offsetEndMinutes,
          sortOrder: i,
        );
      }(),
  ];
}

/// Optional UX default: one full-window direct row per draft participant.
List<SupportSegmentRowDraft> seedDraftSegmentRows({
  required DateTime windowStart,
  required DateTime windowEnd,
  required List<String> participantIds,
  required String? supportItemCode,
  String? supportItemName,
}) {
  final code = supportItemCode?.trim() ?? '';
  if (participantIds.isEmpty) return const [];
  return [
    for (final id in participantIds)
      SupportSegmentRowDraft(
        shiftParticipantId: '',
        participantId: id,
        anchorSupportItemCode: code,
        anchorSupportItemName: supportItemName,
        startAt: windowStart,
        endAt: windowEnd,
      ),
  ];
}
