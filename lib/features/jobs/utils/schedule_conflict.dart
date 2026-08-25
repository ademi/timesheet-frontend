import '../../shifts/data/models/shift_models.dart';
import '../../visits/data/models/visit_models.dart';

/// Half-open range overlap: `[aStart, aEnd)` intersects `[bStart, bEnd)`.
bool rangesOverlap(
  DateTime aStart,
  DateTime aEnd,
  DateTime bStart,
  DateTime bEnd,
) {
  return aStart.isBefore(bEnd) && bStart.isBefore(aEnd);
}

enum ClientConflictKind { visit, shiftHole }

class ClientConflict {
  const ClientConflict({
    required this.kind,
    required this.id,
  });

  final ClientConflictKind kind;
  final String id;

  String get chipLabel => switch (kind) {
        ClientConflictKind.visit => 'Overlapping visit…',
        ClientConflictKind.shiftHole => 'Open shift hole…',
      };
}

/// Client-window conflicts for the proposed schedule (warn-only).
List<ClientConflict> buildClientConflicts({
  required DateTime windowStart,
  required DateTime windowEnd,
  required List<VisitOut> visits,
  required List<ShiftOut> shifts,
}) {
  final out = <ClientConflict>[];
  for (final v in visits) {
    if (v.isCancelled) continue;
    if (!rangesOverlap(
      windowStart,
      windowEnd,
      v.scheduledStart,
      v.scheduledEnd,
    )) {
      continue;
    }
    out.add(ClientConflict(kind: ClientConflictKind.visit, id: v.id));
  }
  for (final s in shifts) {
    if (s.status == 'cancelled') continue;
    if (s.openSlots <= 0) continue;
    if (!rangesOverlap(
      windowStart,
      windowEnd,
      s.scheduledStart,
      s.scheduledEnd,
    )) {
      continue;
    }
    out.add(ClientConflict(kind: ClientConflictKind.shiftHole, id: s.id));
  }
  return out;
}
