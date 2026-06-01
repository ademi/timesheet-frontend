import '../data/models/attendance/employee_model.dart';

String formatEmployeeClockDuration(EmployeeModel employee) {
  final base = employee.clockedInDurationSeconds;
  final clockInAt = employee.currentClockInAt;
  if (base == null && (clockInAt == null || clockInAt.isEmpty)) {
    return '';
  }

  var totalSeconds = base ?? 0;
  if (clockInAt != null && clockInAt.isNotEmpty) {
    final parsed = DateTime.tryParse(clockInAt);
    if (parsed != null) {
      totalSeconds =
          DateTime.now().toUtc().difference(parsed.toUtc()).inSeconds;
    }
  }
  if (totalSeconds < 0) totalSeconds = 0;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  final hh = hours.toString().padLeft(2, '0');
  final mm = minutes.toString().padLeft(2, '0');
  final ss = seconds.toString().padLeft(2, '0');
  return '$hh:$mm:$ss';
}

String employeeContactSubtitle(EmployeeModel employee) {
  if (employee.phone.isNotEmpty) return employee.phone;
  if (employee.employeeCode.isNotEmpty) return employee.employeeCode;
  return '';
}

String employeeClockStatusLabel(EmployeeModel employee, String durationText) {
  if (employee.clockedIn && durationText.isNotEmpty) {
    return 'Clocked in for $durationText';
  }
  if (employee.clockedOut) {
    return 'Clocked out';
  }
  return 'Not clocked in';
}
