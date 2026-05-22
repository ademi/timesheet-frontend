import 'payroll_date_utils.dart';

class PeriodOut {
  const PeriodOut({
    required this.id,
    required this.tenantId,
    required this.periodStart,
    required this.periodEnd,
    required this.status,
    this.closedAt,
    required this.createdAt,
  });

  final String id;
  final String tenantId;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String status;
  final DateTime? closedAt;
  final DateTime createdAt;

  factory PeriodOut.fromJson(Map<String, dynamic> json) {
    return PeriodOut(
      id: json['id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      periodStart: parsePayrollDate(json['period_start'] as String? ?? ''),
      periodEnd: parsePayrollDate(json['period_end'] as String? ?? ''),
      status: json['status'] as String? ?? 'open',
      closedAt: parsePayrollDateOrNull(json['closed_at']),
      createdAt: parsePayrollDate(json['created_at'] as String? ?? ''),
    );
  }
}
