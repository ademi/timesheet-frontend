import '../data/models/visit_models.dart';

class ClientVisitPartition {
  const ClientVisitPartition({
    required this.upcoming,
    required this.past,
  });
  final List<VisitOut> upcoming;
  final List<VisitOut> past;
}

/// Splits visits for detail screens. Cancelled excluded.
/// Upcoming: scheduled/checked_in with end >= now (or status checked_in).
/// Past: completed, or scheduled_end < now (non-cancelled).
ClientVisitPartition partitionClientVisits(
  List<VisitOut> visits, {
  required DateTime now,
}) {
  final upcoming = <VisitOut>[];
  final past = <VisitOut>[];
  for (final v in visits) {
    if (v.isCancelled) continue;
    final isPast = v.isCompleted || v.scheduledEnd.isBefore(now);
    if (isPast && !v.isCheckedIn) {
      past.add(v);
    } else {
      upcoming.add(v);
    }
  }
  upcoming.sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));
  past.sort((a, b) => b.scheduledStart.compareTo(a.scheduledStart));
  return ClientVisitPartition(upcoming: upcoming, past: past);
}

const clientVisitLookahead = Duration(days: 30);
const clientVisitLookback = Duration(days: 30);
const clientVisitFetchLimit = 100;
