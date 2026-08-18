/// Which review actions are available for a credential given its latest decision.
class CredentialReviewButtonState {
  const CredentialReviewButtonState({
    required this.acceptEnabled,
    required this.rejectEnabled,
    required this.reReviewEnabled,
  });

  final bool acceptEnabled;
  final bool rejectEnabled;
  final bool reReviewEnabled;

  static const pending = CredentialReviewButtonState(
    acceptEnabled: true,
    rejectEnabled: true,
    reReviewEnabled: false,
  );

  static const decided = CredentialReviewButtonState(
    acceptEnabled: false,
    rejectEnabled: false,
    reReviewEnabled: true,
  );

  static const awaitingReReview = CredentialReviewButtonState(
    acceptEnabled: true,
    rejectEnabled: true,
    reReviewEnabled: false,
  );
}

CredentialReviewButtonState credentialReviewButtonState(String? decision) {
  return switch (decision) {
    'accepted' || 'rejected' => CredentialReviewButtonState.decided,
    're_review_required' => CredentialReviewButtonState.awaitingReReview,
    _ => CredentialReviewButtonState.pending,
  };
}
