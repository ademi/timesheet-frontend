import 'payroll_date_utils.dart';

class ResultOut {
  const ResultOut({
    required this.id,
    required this.tenantId,
    required this.periodId,
    required this.employeeId,
    this.employeeName,
    required this.regularMinutes,
    required this.weekendMinutes,
    required this.nightMinutes,
    required this.overtimeMinutes,
    required this.amountDue,
    required this.rateSnapshot,
    required this.calcSnapshot,
    this.recalculatedAt,
    required this.createdAt,
  });

  final String id;
  final String tenantId;
  final String periodId;
  final String employeeId;
  final String? employeeName;
  final int regularMinutes;
  final int weekendMinutes;
  final int nightMinutes;
  final int overtimeMinutes;
  final double amountDue;
  final Map<String, dynamic> rateSnapshot;
  final Map<String, dynamic> calcSnapshot;
  final DateTime? recalculatedAt;
  final DateTime createdAt;

  factory ResultOut.fromJson(Map<String, dynamic> json) {
    return ResultOut(
      id: json['id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      periodId: json['period_id'] as String? ?? '',
      employeeId: json['employee_id'] as String? ?? '',
      employeeName: json['employee_name'] as String?,
      regularMinutes: payrollAsInt(json['regular_minutes']),
      weekendMinutes: payrollAsInt(json['weekend_minutes']),
      nightMinutes: payrollAsInt(json['night_minutes']),
      overtimeMinutes: payrollAsInt(json['overtime_minutes']),
      amountDue: payrollAsDouble(json['amount_due']),
      rateSnapshot: Map<String, dynamic>.from(
        json['rate_snapshot'] as Map? ?? {},
      ),
      calcSnapshot: Map<String, dynamic>.from(
        json['calc_snapshot'] as Map? ?? {},
      ),
      recalculatedAt: parsePayrollDateOrNull(json['recalculated_at']),
      createdAt: parsePayrollDate(json['created_at'] as String? ?? ''),
    );
  }
}
