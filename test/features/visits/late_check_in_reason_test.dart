import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/visits/data/models/visit_models.dart';

void main() {
  test('isLateCheckIn respects grace window', () {
    final start = DateTime.utc(2026, 9, 23, 9);
    expect(
      isLateCheckIn(
        scheduledStart: start,
        tapTime: start.add(const Duration(minutes: 4)),
      ),
      isFalse,
    );
    expect(
      isLateCheckIn(
        scheduledStart: start,
        tapTime: start.add(const Duration(minutes: 6)),
      ),
      isTrue,
    );
  });

  test('VisitGpsBody includes late_reason_code when set', () {
    final body = VisitGpsBody(
      locationStatus: 'unavailable',
      locationFailReason: 'offline',
      deviceOffline: true,
      lateReasonCode: 'traffic',
    );
    expect(body.toJson()['late_reason_code'], 'traffic');
  });
}
