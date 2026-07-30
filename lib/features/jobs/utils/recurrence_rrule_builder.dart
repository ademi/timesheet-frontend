enum RecurrenceFrequency { daily, weekly, fortnightly, monthly }

const weekdayRruleCodes = <int, String>{
  DateTime.monday: 'MO',
  DateTime.tuesday: 'TU',
  DateTime.wednesday: 'WE',
  DateTime.thursday: 'TH',
  DateTime.friday: 'FR',
  DateTime.saturday: 'SA',
  DateTime.sunday: 'SU',
};

String compileRecurrenceRrule({
  required RecurrenceFrequency frequency,
  Set<int> weekdays = const {},
}) {
  switch (frequency) {
    case RecurrenceFrequency.daily:
      return 'FREQ=DAILY';
    case RecurrenceFrequency.monthly:
      return 'FREQ=MONTHLY';
    case RecurrenceFrequency.weekly:
    case RecurrenceFrequency.fortnightly:
      final days = weekdays.toList()..sort();
      if (days.isEmpty) {
        throw ArgumentError.value(
          weekdays,
          'weekdays',
          'is required for weekly recurrence',
        );
      }
      final byDay = days.map((day) => weekdayRruleCodes[day]).join(',');
      final interval =
          frequency == RecurrenceFrequency.fortnightly ? ';INTERVAL=2' : '';
      return 'FREQ=WEEKLY$interval;BYDAY=$byDay';
  }
}
