import 'payroll_date_utils.dart';

class EmployeeBalanceOut {
  const EmployeeBalanceOut({
    required this.employeeId,
    required this.totalOwed,
    required this.totalPaid,
    required this.outstanding,
    required this.currencyCode,
  });

  final String employeeId;
  final double totalOwed;
  final double totalPaid;
  final double outstanding;
  final String currencyCode;

  factory EmployeeBalanceOut.fromJson(Map<String, dynamic> json) {
    return EmployeeBalanceOut(
      employeeId: json['employee_id'] as String? ?? '',
      totalOwed: payrollAsDouble(json['total_owed']),
      totalPaid: payrollAsDouble(json['total_paid']),
      outstanding: payrollAsDouble(json['outstanding']),
      currencyCode: json['currency_code'] as String? ?? 'USD',
    );
  }
}
