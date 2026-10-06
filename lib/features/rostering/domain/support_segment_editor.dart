/// Editable support-segment row (post-assign UI + client-side checks).
class SupportSegmentRowDraft {
  SupportSegmentRowDraft({
    required this.shiftParticipantId,
    required this.anchorSupportItemCode,
    required this.startAt,
    required this.endAt,
    this.anchorSupportItemName,
    this.kind = 'direct',
  });

  String shiftParticipantId;
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

String supportSegmentKindLabel(String kind) => switch (kind) {
  'sleepover' => 'Sleepover',
  'shadow' => 'Shadow',
  'irregular_sil' => 'Irregular SIL',
  _ => 'Direct',
};

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

/// Client-side checks before PUT replace. Returns a staff-facing message or null.
String? validateSupportSegmentRows({
  required List<SupportSegmentRowDraft> rows,
  required DateTime visitStart,
  required DateTime visitEnd,
  required Set<String> activeShiftParticipantIds,
}) {
  if (rows.isEmpty) {
    return 'Add at least one segment before saving.';
  }

  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    final n = i + 1;
    if (row.shiftParticipantId.trim().isEmpty) {
      return 'Segment $n needs a participant.';
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
  }

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

  for (var i = 0; i < rows.length; i++) {
    for (var j = i + 1; j < rows.length; j++) {
      final a = rows[i];
      final b = rows[j];
      if (a.shiftParticipantId != b.shiftParticipantId) continue;
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
