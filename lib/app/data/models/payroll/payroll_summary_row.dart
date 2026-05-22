import 'payroll_date_utils.dart';

class PayrollSummaryRow {
  const PayrollSummaryRow({
    required this.employeeId,
    required this.fullName,
    required this.regularMinutes,
    required this.weekendMinutes,
    required this.nightMinutes,
    required this.overtimeMinutes,
    required this.amountDue,
    required this.minutes,
  });

  final String employeeId;
  final String fullName;
  final int regularMinutes;
  final int weekendMinutes;
  final int nightMinutes;
  final int overtimeMinutes;
  final double amountDue;
  final double minutes;

  factory PayrollSummaryRow.fromJson(Map<String, dynamic> json) {
    return PayrollSummaryRow(
      employeeId: json['employee_id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      regularMinutes: payrollAsInt(json['regular_minutes']),
      weekendMinutes: payrollAsInt(json['weekend_minutes']),
      nightMinutes: payrollAsInt(json['night_minutes']),
      overtimeMinutes: payrollAsInt(json['overtime_minutes']),
      amountDue: payrollAsDouble(json['amount_due']),
      minutes: payrollAsDouble(json['minutes']),
    );
  }
}
