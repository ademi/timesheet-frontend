import '../data/models/job_models.dart';

String recurrenceLabel(RecurrenceRuleOut rule) {
  final fields = <String, String>{
    for (final field in rule.rrule.split(';'))
      if (field.contains('=')) field.split('=').first: field.split('=').last,
  };
  final frequency = fields['FREQ'];
  final interval = fields['INTERVAL'];
  final days = (fields['BYDAY'] ?? '')
      .split(',')
      .where((day) => day.isNotEmpty)
      .map(_weekdayLabel)
      .join(', ');
  final pattern = switch (frequency) {
    'DAILY' => 'Every day',
    'MONTHLY' => 'Every month',
    'WEEKLY' when interval == '2' =>
      'Every fortnight${days.isEmpty ? '' : ' on $days'}',
    'WEEKLY' => 'Every${days.isEmpty ? ' week' : ' $days'}',
    _ => 'Repeats',
  };
  final windows = rule.timeWindows.map(_formatWindow).join(' and ');
  final from = _formatDate(rule.dtstart);
  final until = rule.until == null ? '' : ' until ${_formatDate(rule.until!)}';
  return '$pattern · $windows · from $from$until';
}

/// Pre-filled workers plus any slots still open, e.g. "Jane, Ali · 1 open".
String recurrenceWorkersLabel(RecurrenceRuleOut rule) {
  final names = rule.contractorNames.isNotEmpty
      ? rule.contractorNames
      : rule.contractorIds;
  final open = rule.requiredSlots - rule.contractorIds.length;
  if (names.isEmpty) return 'Unfilled';
  if (open <= 0) return names.join(', ');
  return '${names.join(', ')} · $open open';
}

String _weekdayLabel(String code) =>
    const {
      'MO': 'Mon',
      'TU': 'Tue',
      'WE': 'Wed',
      'TH': 'Thu',
      'FR': 'Fri',
      'SA': 'Sat',
      'SU': 'Sun',
    }[code] ??
    code;

String _formatWindow(TimeWindow window) =>
    '${_formatTime(window.startTime)} – ${_formatTime(window.endTime)}';

String _formatTime(String value) {
  final parts = value.split(':');
  final hour = int.tryParse(parts.first) ?? 0;
  final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
  final suffix = hour < 12 ? 'am' : 'pm';
  return minute == 0
      ? '$displayHour:00 $suffix'
      : '$displayHour:${minute.toString().padLeft(2, '0')} $suffix';
}

String _formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
