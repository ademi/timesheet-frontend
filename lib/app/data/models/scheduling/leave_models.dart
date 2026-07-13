import 'scheduling_date_utils.dart';

class LeaveCreateRequest {
  const LeaveCreateRequest({
    required this.employeeId,
    required this.startDate,
    required this.endDate,
    required this.leaveType,
    this.notes,
  });

  final String employeeId;
  final DateTime startDate;
  final DateTime endDate;
  final String leaveType;
  final String? notes;

  Map<String, dynamic> toJson() => {
        'employee_id': employeeId,
        'start_date': fmtSchedulingDate(startDate),
        'end_date': fmtSchedulingDate(endDate),
        'leave_type': leaveType,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
      };
}

class LeaveOut {
  const LeaveOut({
    required this.id,
    required this.employeeId,
    required this.startDate,
    required this.endDate,
    required this.leaveType,
    this.notes,
  });

  final String id;
  final String employeeId;
  final DateTime startDate;
  final DateTime endDate;
  final String leaveType;
  final String? notes;

  factory LeaveOut.fromJson(Map<String, dynamic> json) {
    return LeaveOut(
      id: json['id'] as String? ?? '',
      employeeId: json['employee_id'] as String? ?? '',
      startDate: parseSchedulingDate(json['start_date'] as String? ?? ''),
      endDate: parseSchedulingDate(json['end_date'] as String? ?? ''),
      leaveType: json['leave_type'] as String? ?? 'other',
      notes: json['notes'] as String?,
    );
  }
}
