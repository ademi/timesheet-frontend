import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/jobs/data/models/job_models.dart';
import 'package:rostiq/features/jobs/utils/time_window_utils.dart';

void main() {
  test('coerceEndTime maps midnight to 23:59', () {
    expect(coerceEndTime('00:00'), '23:59');
  });

  test('coerceEndTime leaves other times unchanged', () {
    expect(coerceEndTime('12:00'), '12:00');
    expect(coerceEndTime('23:59'), '23:59');
  });

  test('validateVisitWindows rejects overlapping windows', () {
    expect(
      validateVisitWindows(const [
        TimeWindow(startTime: '09:00', endTime: '12:00'),
        TimeWindow(startTime: '11:00', endTime: '14:00'),
      ]),
      windowsOverlapError,
    );
  });

  test('validateVisitWindows accepts coerced midnight end', () {
    expect(
      validateVisitWindows(const [
        TimeWindow(startTime: '09:00', endTime: '00:00'),
      ]),
      isNull,
    );
  });

  test('validateVisitWindows rejects end before start after coerce', () {
    expect(
      validateVisitWindows(const [
        TimeWindow(startTime: '23:59', endTime: '00:00'),
      ]),
      endBeforeStartError,
    );
  });
}
