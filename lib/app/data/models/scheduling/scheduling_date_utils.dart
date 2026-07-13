import 'package:flutter/material.dart';

String fmtSchedulingDate(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

DateTime parseSchedulingDate(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed != null) return DateTime(parsed.year, parsed.month, parsed.day);
  throw FormatException('Invalid date: $value');
}

DateTime? parseSchedulingDateOrNull(dynamic value) {
  if (value == null) return null;
  if (value is! String || value.isEmpty) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}

/// Monday of the week containing [date] (locale week start = Monday).
DateTime mondayOfWeek(DateTime date) {
  final local = DateTime(date.year, date.month, date.day);
  return local.subtract(Duration(days: local.weekday - DateTime.monday));
}

DateTime sundayOfWeek(DateTime date) =>
    mondayOfWeek(date).add(const Duration(days: 6));

Color? parseSchedulingColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  var value = hex.replaceFirst('#', '');
  if (value.length == 6) value = 'FF$value';
  final parsed = int.tryParse(value, radix: 16);
  if (parsed == null) return null;
  return Color(parsed);
}
