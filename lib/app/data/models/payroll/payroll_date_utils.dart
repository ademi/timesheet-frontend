String fmtPayrollDate(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

DateTime parsePayrollDate(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed != null) return parsed;
  throw FormatException('Invalid date: $value');
}

DateTime? parsePayrollDateOrNull(dynamic value) {
  if (value == null) return null;
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

double payrollAsDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

int payrollAsInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

int? payrollAsIntOrNull(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String && value.isNotEmpty) return int.tryParse(value);
  return null;
}

String payrollTimeAsString(dynamic value) {
  if (value is String) return value;
  return value?.toString() ?? '';
}
