import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/visits/sync/sync_error_classifier.dart';

void main() {
  test('invalid_visit_status is terminal; 503 is retryable', () {
    expect(
      classifySyncFailure(statusCode: 409, detail: 'invalid_visit_status'),
      SyncFailureClass.terminal,
    );
    expect(
      classifySyncFailure(statusCode: 403, detail: 'not_visit_assignee'),
      SyncFailureClass.terminal,
    );
    expect(
      classifySyncFailure(statusCode: 503, detail: null),
      SyncFailureClass.retryable,
    );
    expect(
      classifySyncFailure(statusCode: null, detail: null),
      SyncFailureClass.retryable,
    ); // network
  });
}
