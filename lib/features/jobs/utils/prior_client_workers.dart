import '../../visits/data/models/visit_models.dart';

/// Default lookback for ranking workers who previously visited a client.
const priorClientWorkerLookback = Duration(days: 90);

/// Cap for prior-visit fetch used by Assign ranking.
const priorClientWorkerFetchLimit = 200;

/// Badge copy on Assign worker dropdowns.
const workedWithClientLabel = 'Worked with client';

/// Counts non-cancelled visits per contractor (most recent wins ties via sort).
Map<String, int> countPriorClientVisits(Iterable<VisitOut> visits) {
  final counts = <String, int>{};
  for (final visit in visits) {
    if (visit.isCancelled) continue;
    final id = visit.contractorId.trim();
    if (id.isEmpty) continue;
    counts[id] = (counts[id] ?? 0) + 1;
  }
  return counts;
}

/// Whether [contractorId] has any prior non-cancelled visit with the client.
bool hasPriorClientVisits(
  String contractorId, {
  required Map<String, int> counts,
}) {
  return (counts[contractorId] ?? 0) > 0;
}

/// Sort key: higher prior visit count first, then [nameOf] ascending.
int comparePriorThenName({
  required String aId,
  required String bId,
  required String aName,
  required String bName,
  required Map<String, int> counts,
  required int Function(String, String) nameCompare,
}) {
  final ac = counts[aId] ?? 0;
  final bc = counts[bId] ?? 0;
  if (ac != bc) return bc.compareTo(ac);
  return nameCompare(aName, bName);
}
