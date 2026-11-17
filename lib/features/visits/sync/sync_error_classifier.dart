/// Classifies clock sync HTTP failures as terminal (report conflict) vs retryable.
library;

enum SyncFailureClass { terminal, retryable }

const Set<String> kTerminalSyncFailureDetails = {
  'invalid_visit_status',
  'not_visit_assignee',
  'visit_not_found',
  'geofence_rejected',
  'tap_time_out_of_skew',
  'clock_overlap',
};

/// Network / unknown → retryable; known terminal 4xx details → terminal;
/// 408/429 → retryable (timeout / rate limit); other 4xx → terminal; 5xx → retryable.
SyncFailureClass classifySyncFailure({int? statusCode, String? detail}) {
  if (statusCode == null) return SyncFailureClass.retryable;
  if (statusCode >= 500) return SyncFailureClass.retryable;
  // Mirror form/media outbox: request timeout and rate limits are transient.
  if (statusCode == 408 || statusCode == 429) {
    return SyncFailureClass.retryable;
  }
  if (statusCode >= 400 && statusCode < 500) {
    if (detail != null && kTerminalSyncFailureDetails.contains(detail)) {
      return SyncFailureClass.terminal;
    }
    return SyncFailureClass.terminal;
  }
  return SyncFailureClass.retryable;
}
