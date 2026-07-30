import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/jobs/utils/recurrence_rrule_builder.dart';

void main() {
  test('compiles selected weekdays into a weekly RRULE', () {
    expect(
      compileRecurrenceRrule(
        frequency: RecurrenceFrequency.weekly,
        weekdays: const {1, 3, 5},
      ),
      'FREQ=WEEKLY;BYDAY=MO,WE,FR',
    );
  });

  test('compiles fortnightly recurrence with two-week interval', () {
    expect(
      compileRecurrenceRrule(
        frequency: RecurrenceFrequency.fortnightly,
        weekdays: const {2},
      ),
      'FREQ=WEEKLY;INTERVAL=2;BYDAY=TU',
    );
  });

  test('compiles daily and monthly recurrence patterns', () {
    expect(
      compileRecurrenceRrule(frequency: RecurrenceFrequency.daily),
      'FREQ=DAILY',
    );
    expect(
      compileRecurrenceRrule(frequency: RecurrenceFrequency.monthly),
      'FREQ=MONTHLY',
    );
  });
}
