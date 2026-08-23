import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/jobs/data/models/job_models.dart';
import 'package:rostiq/features/jobs/utils/time_window_utils.dart';

void main() {
  test('defaultRecurrenceEndDate is one year after start', () {
    final start = DateTime(2026, 3, 15);
    expect(defaultRecurrenceEndDate(start), DateTime(2027, 3, 15));
  });

  test('recurrenceUntilInstant is end of civil day', () {
    final end = DateTime(2027, 3, 15);
    final until = recurrenceUntilInstant(end);
    expect(until.year, 2027);
    expect(until.month, 3);
    expect(until.day, 15);
    expect(until.hour, 23);
    expect(until.minute, 59);
  });

  test('validateVisitWindows rejects midnight end as overnight', () {
    expect(
      validateVisitWindows(const [
        TimeWindow(startTime: '09:00', endTime: '00:00'),
      ]),
      endBeforeStartError,
    );
  });

  test('validateVisitWindows rejects end before start', () {
    expect(
      validateVisitWindows(const [
        TimeWindow(startTime: '14:00', endTime: '12:00'),
      ]),
      endBeforeStartError,
    );
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

  test('validateVisitWindows accepts same-day window ending at 23:59', () {
    expect(
      validateVisitWindows(const [
        TimeWindow(startTime: '09:00', endTime: '23:59'),
      ]),
      isNull,
    );
  });
}
