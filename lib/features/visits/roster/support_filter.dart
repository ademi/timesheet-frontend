import '../../jobs/data/models/job_models.dart';

/// Open jobs (ongoing support) belonging to a single client.
///
/// Client-first roster: the client dropdown is primary. A per-support sub-filter
/// only makes sense when a client has more than one open support (D3).
List<JobOut> jobsForClientFilter(
  List<JobOut> jobs, {
  required String clientId,
}) =>
    jobs
        .where((j) => j.clientId == clientId && j.status == 'open')
        .toList(growable: false);

/// Whether to surface the support/job sub-filter for the selected client.
///
/// Hidden unless a client is selected and that client has >1 open support (D3).
bool shouldShowSupportFilter(
  List<JobOut> jobs, {
  required String? clientId,
}) {
  if (clientId == null || clientId.isEmpty) return false;
  return jobsForClientFilter(jobs, clientId: clientId).length > 1;
}
