/// Aggregated summary for the contractor home dashboard (client-side from list APIs).
class ContractorHomeStats {
  const ContractorHomeStats({
    this.visitsUpcoming = 0,
    this.visitsToday = 0,
    this.visitsCompletedTotal = 0,
    this.visitsPaidTotal = 0,
    this.visitsUnpaidCompleted = 0,
    this.engagementsActive = 0,
    this.engagementsTotal = 0,
    this.credentialsTotal = 0,
    this.credentialsApproved = 0,
    this.credentialsMissingEvidence = 0,
    this.credentialsPendingReview = 0,
  });

  /// Upcoming visits in the next 14 days (scheduled/in-progress).
  final int visitsUpcoming;

  /// Visits scheduled for today.
  final int visitsToday;

  /// All-time completed visits.
  final int visitsCompletedTotal;

  /// Completed visits with payment_status == 'paid'.
  final int visitsPaidTotal;

  /// Completed visits still unpaid.
  final int visitsUnpaidCompleted;

  /// Active engagements.
  final int engagementsActive;

  /// Total engagements (any status).
  final int engagementsTotal;

  /// Total credential records.
  final int credentialsTotal;

  /// Credentials with status == 'approved'.
  final int credentialsApproved;

  /// Credentials with evidence_presence == 'absent' (need upload).
  final int credentialsMissingEvidence;

  /// Credentials pending staff review.
  final int credentialsPendingReview;

  static const empty = ContractorHomeStats();
}
