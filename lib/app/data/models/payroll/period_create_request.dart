import 'payroll_date_utils.dart';

class PeriodCreateRequest {
  const PeriodCreateRequest({
    required this.periodStart,
    required this.periodEnd,
    this.branchId,
  });

  final DateTime periodStart;
  final DateTime periodEnd;
  final String? branchId;

  Map<String, dynamic> toJson() => {
    'period_start': fmtPayrollDate(periodStart),
    'period_end': fmtPayrollDate(periodEnd),
    if (branchId != null && branchId!.isNotEmpty) 'branch_id': branchId,
  };
}
