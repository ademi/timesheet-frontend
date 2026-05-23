import 'payroll_date_utils.dart';

class RateOut {
  const RateOut({
    required this.id,
    required this.tenantId,
    required this.employeeId,
    required this.effectiveFrom,
    this.effectiveTo,
    required this.baseRate,
    required this.weekendRate,
    required this.nightRate,
    required this.overtimeRate,
    this.overtimeDailyThresholdMinutes,
    this.overtimeWeeklyThresholdMinutes,
    required this.nightShiftStart,
    required this.nightShiftEnd,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String tenantId;
  final String employeeId;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;
  final double baseRate;
  final double weekendRate;
  final double nightRate;
  final double overtimeRate;
  final int? overtimeDailyThresholdMinutes;
  final int? overtimeWeeklyThresholdMinutes;
  final String nightShiftStart;
  final String nightShiftEnd;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory RateOut.fromJson(Map<String, dynamic> json) {
    return RateOut(
      id: json['id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      employeeId: json['employee_id'] as String? ?? '',
      effectiveFrom: parsePayrollDate(json['effective_from'] as String? ?? ''),
      effectiveTo: parsePayrollDateOrNull(json['effective_to']),
      baseRate: payrollAsDouble(json['base_rate']),
      weekendRate: payrollAsDouble(json['weekend_rate']),
      nightRate: payrollAsDouble(json['night_rate']),
      overtimeRate: payrollAsDouble(json['overtime_rate']),
      overtimeDailyThresholdMinutes:
          payrollAsIntOrNull(json['overtime_daily_threshold_minutes']),
      overtimeWeeklyThresholdMinutes:
          payrollAsIntOrNull(json['overtime_weekly_threshold_minutes']),
      nightShiftStart: payrollTimeAsString(json['night_shift_start']),
      nightShiftEnd: payrollTimeAsString(json['night_shift_end']),
      createdAt: parsePayrollDate(json['created_at'] as String? ?? ''),
      updatedAt: parsePayrollDate(json['updated_at'] as String? ?? ''),
    );
  }
}
