import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/credentials/widgets/credential_review_actions.dart';

void main() {
  test('pending credentials allow accept and reject only', () {
    const state = CredentialReviewButtonState.pending;
    expect(state.acceptEnabled, isTrue);
    expect(state.rejectEnabled, isTrue);
    expect(state.reReviewEnabled, isFalse);
    expect(credentialReviewButtonState(null), state);
  });

  test('accepted or rejected credentials allow re-review only', () {
    const state = CredentialReviewButtonState.decided;
    expect(state.acceptEnabled, isFalse);
    expect(state.rejectEnabled, isFalse);
    expect(state.reReviewEnabled, isTrue);
    expect(credentialReviewButtonState('accepted'), state);
    expect(credentialReviewButtonState('rejected'), state);
  });

  test('re-review required credentials allow accept and reject again', () {
    const state = CredentialReviewButtonState.awaitingReReview;
    expect(state.acceptEnabled, isTrue);
    expect(state.rejectEnabled, isTrue);
    expect(state.reReviewEnabled, isFalse);
    expect(credentialReviewButtonState('re_review_required'), state);
  });
}
