import 'package:flutter/material.dart';

import '../../data/models/scheduling/scheduling_date_utils.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String formatSchedulingShortDate(DateTime date) {
  return '${_weekdays[date.weekday - DateTime.monday]} '
      '${date.day} ${_months[date.month - 1]}';
}

String formatWeekRangeLabel(DateTime weekStart) {
  final end = sundayOfWeek(weekStart);
  return '${formatSchedulingShortDate(weekStart)} – ${formatSchedulingShortDate(end)}';
}

String formatTimeOfDay(String? value) {
  if (value == null || value.isEmpty) return '';
  if (value.length >= 5) return value.substring(0, 5);
  return value;
}

Color? parseScheduleColor(String? hex, {Color? fallback}) =>
    parseSchedulingColor(hex) ?? fallback;
