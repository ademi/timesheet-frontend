/// A single audit-trail row from
/// `GET /v1/attendance/time-entries/{time_entry_id}/adjustments`.
class AttendanceAdjustmentHistory {
  const AttendanceAdjustmentHistory({
    required this.action,
    this.reason,
    this.adminUserId,
    this.employeeConfirmationStatus,
    this.oldClockInAt,
    this.oldClockOutAt,
    this.newClockInAt,
    this.newClockOutAt,
    this.createdAt,
  });

  final String action;
  final String? reason;
  final String? adminUserId;
  final String? employeeConfirmationStatus;
  final DateTime? oldClockInAt;
  final DateTime? oldClockOutAt;
  final DateTime? newClockInAt;
  final DateTime? newClockOutAt;
  final DateTime? createdAt;

  static DateTime? _parse(dynamic value) =>
      value is String ? DateTime.tryParse(value) : null;

  factory AttendanceAdjustmentHistory.fromJson(Map<String, dynamic> json) {
    return AttendanceAdjustmentHistory(
      action: json['action'] as String? ?? '',
      reason: json['reason'] as String?,
      adminUserId: json['admin_user_id'] as String?,
      employeeConfirmationStatus:
          json['employee_confirmation_status'] as String?,
      oldClockInAt: _parse(json['old_clock_in_at']),
      oldClockOutAt: _parse(json['old_clock_out_at']),
      newClockInAt: _parse(json['new_clock_in_at']),
      newClockOutAt: _parse(json['new_clock_out_at']),
      createdAt: _parse(json['created_at']),
    );
  }
}
