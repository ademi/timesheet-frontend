import '../../../shared/utils/name_sort.dart';
import '../../jobs/data/models/job_models.dart';

/// Open jobs (ongoing support) belonging to a single client.
///
/// Client-first roster: the client dropdown is primary. A per-support sub-filter
/// only makes sense when a client has more than one open support (D3).
List<JobOut> jobsForClientFilter(
  List<JobOut> jobs, {
  required String clientId,
}) => sortedByName(
  jobs.where((j) => j.clientId == clientId && j.status == 'open'),
  (j) => j.title,
);

/// Open jobs available in the Support filter for the current client selection.
///
/// - Client selected → that client's open supports
/// - All clients → every open support (so SIL fill / job titles stay findable)
List<JobOut> jobsForSupportFilter(
  List<JobOut> jobs, {
  required String? clientId,
}) {
  if (clientId == null || clientId.isEmpty) {
    return sortedByName(
      jobs.where((j) => j.status == 'open'),
      (j) => j.title,
    );
  }
  return jobsForClientFilter(jobs, clientId: clientId);
}

/// Whether to surface the Support/job filter.
///
/// - All clients: show when any open job exists
/// - One client: show only when that client has >1 open support (D3)
bool shouldShowSupportFilter(List<JobOut> jobs, {required String? clientId}) {
  final options = jobsForSupportFilter(jobs, clientId: clientId);
  if (clientId == null || clientId.isEmpty) return options.isNotEmpty;
  return options.length > 1;
}
