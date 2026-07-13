import 'scheduling_date_utils.dart';

class AssignmentUpsertRequest {
  const AssignmentUpsertRequest({
    required this.employeeId,
    required this.workDate,
    this.templateId,
    this.isDayOff = false,
    this.notes,
  });

  final String employeeId;
  final DateTime workDate;
  final String? templateId;
  final bool isDayOff;
  final String? notes;

  Map<String, dynamic> toJson() => {
        'employee_id': employeeId,
        'work_date': fmtSchedulingDate(workDate),
        'template_id': templateId,
        'is_day_off': isDayOff,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
      };
}

class AssignmentOut {
  const AssignmentOut({
    required this.id,
    required this.employeeId,
    required this.workDate,
    this.templateId,
    required this.isDayOff,
    this.notes,
  });

  final String id;
  final String employeeId;
  final DateTime workDate;
  final String? templateId;
  final bool isDayOff;
  final String? notes;

  factory AssignmentOut.fromJson(Map<String, dynamic> json) {
    return AssignmentOut(
      id: json['id'] as String? ?? '',
      employeeId: json['employee_id'] as String? ?? '',
      workDate: parseSchedulingDate(json['work_date'] as String? ?? ''),
      templateId: json['template_id'] as String?,
      isDayOff: json['is_day_off'] as bool? ?? false,
      notes: json['notes'] as String?,
    );
  }
}

class BulkAssignmentItem {
  const BulkAssignmentItem({
    required this.employeeId,
    required this.workDate,
  });

  final String employeeId;
  final DateTime workDate;

  Map<String, dynamic> toJson() => {
        'employee_id': employeeId,
        'work_date': fmtSchedulingDate(workDate),
      };
}

class BulkAssignmentRequest {
  const BulkAssignmentRequest({
    required this.templateId,
    required this.items,
    this.isDayOff = false,
  });

  final String templateId;
  final List<BulkAssignmentItem> items;
  final bool isDayOff;

  Map<String, dynamic> toJson() => {
        'template_id': templateId,
        'is_day_off': isDayOff,
        'items': items.map((e) => e.toJson()).toList(),
      };
}

class BulkAssignmentResult {
  const BulkAssignmentResult({required this.copiedCount});

  final int copiedCount;

  factory BulkAssignmentResult.fromJson(Map<String, dynamic> json) {
    return BulkAssignmentResult(
      copiedCount: json['copied_count'] as int? ?? 0,
    );
  }
}
