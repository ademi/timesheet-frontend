import 'payroll_date_utils.dart';

class PeriodCreateRequest {
  const PeriodCreateRequest({
    required this.periodStart,
    required this.periodEnd,
  });

  final DateTime periodStart;
  final DateTime periodEnd;

  Map<String, dynamic> toJson() => {
    'period_start': fmtPayrollDate(periodStart),
    'period_end': fmtPayrollDate(periodEnd),
  };
}
