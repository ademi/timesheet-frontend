import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/visits/controllers/contractor_visits_controller.dart';
import 'package:rostiq/features/visits/sync/outbox_models.dart';

ClockOutboxItem _item({
  String? lastError,
  bool isConflict = false,
}) {
  return ClockOutboxItem(
    clientEventId: 'e1',
    visitId: 'v1',
    kind: ClockOutboxKind.checkIn,
    tapTimeIso: '2026-09-07T08:00:00.000Z',
    locationStatus: 'unavailable',
    locationFailReason: 'x',
    deviceOffline: true,
    lastError: lastError,
    isConflict: isConflict,
  );
}

void main() {
  group('clockSyncUiFor', () {
    test('empty → none', () {
      expect(clockSyncUiFor(const []), VisitClockSyncUi.none);
    });

    test('pending without error → pending', () {
      expect(clockSyncUiFor([_item()]), VisitClockSyncUi.pending);
    });

    test('retryable lastError without conflict → pending', () {
      expect(
        clockSyncUiFor([_item(lastError: 'offline')]),
        VisitClockSyncUi.pending,
      );
    });

    test('isConflict → failed', () {
      expect(
        clockSyncUiFor([
          _item(lastError: 'invalid_visit_status', isConflict: true),
        ]),
        VisitClockSyncUi.failed,
      );
    });
  });
}
