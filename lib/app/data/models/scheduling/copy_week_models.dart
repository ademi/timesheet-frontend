import 'scheduling_date_utils.dart';

class CopyWeekRequest {
  const CopyWeekRequest({
    required this.branchId,
    required this.sourceStart,
    required this.targetStart,
    required this.mode,
    this.employeeIds,
  });

  final String branchId;
  final DateTime sourceStart;
  final DateTime targetStart;
  final String mode;
  final List<String>? employeeIds;

  Map<String, dynamic> toJson() => {
        'branch_id': branchId,
        'source_start': fmtSchedulingDate(sourceStart),
        'target_start': fmtSchedulingDate(targetStart),
        'mode': mode,
        if (employeeIds != null && employeeIds!.isNotEmpty)
          'employee_ids': employeeIds,
      };
}

class CopyWeekResult {
  const CopyWeekResult({
    required this.copiedCount,
    required this.mode,
  });

  final int copiedCount;
  final String mode;

  factory CopyWeekResult.fromJson(Map<String, dynamic> json) {
    return CopyWeekResult(
      copiedCount: json['copied_count'] as int? ?? 0,
      mode: json['mode'] as String? ?? 'overrides_only',
    );
  }
}
