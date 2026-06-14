/// Admin correction actions sent to `POST /v1/attendance/adjustments`.
///
/// Employee confirmation actions (`employee_confirm` / `employee_reject`) are
/// intentionally not modelled here yet; they belong to the employee-facing
/// flow that is out of scope for this phase.
enum AdjustmentAction {
  adminAddClockOut('admin_add_clock_out'),
  adminCreateManualEntry('admin_create_manual_entry'),
  adminEditEntry('admin_edit_entry');

  const AdjustmentAction(this.wireValue);

  final String wireValue;
}

class AttendanceAdjustmentRequest {
  const AttendanceAdjustmentRequest._({
    required this.action,
    required this.reason,
    this.timeEntryId,
    this.employeeId,
    this.clockInAt,
    this.clockOutAt,
  });

  /// Employee forgot to clock out; an open time entry already exists.
  factory AttendanceAdjustmentRequest.addClockOut({
    required String timeEntryId,
    required DateTime clockOutAt,
    required String reason,
  }) {
    return AttendanceAdjustmentRequest._(
      action: AdjustmentAction.adminAddClockOut,
      timeEntryId: timeEntryId,
      clockOutAt: clockOutAt,
      reason: reason,
    );
  }

  /// No open time entry exists; admin builds the full corrected entry.
  factory AttendanceAdjustmentRequest.createManualEntry({
    required String employeeId,
    required DateTime clockInAt,
    required DateTime clockOutAt,
    required String reason,
  }) {
    return AttendanceAdjustmentRequest._(
      action: AdjustmentAction.adminCreateManualEntry,
      employeeId: employeeId,
      clockInAt: clockInAt,
      clockOutAt: clockOutAt,
      reason: reason,
    );
  }

  /// Edit an existing entry. Either time may be omitted if unchanged.
  factory AttendanceAdjustmentRequest.editEntry({
    required String timeEntryId,
    DateTime? clockInAt,
    DateTime? clockOutAt,
    required String reason,
  }) {
    return AttendanceAdjustmentRequest._(
      action: AdjustmentAction.adminEditEntry,
      timeEntryId: timeEntryId,
      clockInAt: clockInAt,
      clockOutAt: clockOutAt,
      reason: reason,
    );
  }

  final AdjustmentAction action;
  final String reason;
  final String? timeEntryId;
  final String? employeeId;
  final DateTime? clockInAt;
  final DateTime? clockOutAt;

  Map<String, dynamic> toJson() => {
        'action': action.wireValue,
        if (timeEntryId != null) 'time_entry_id': timeEntryId,
        if (employeeId != null) 'employee_id': employeeId,
        if (clockInAt != null)
          'clock_in_at': clockInAt!.toUtc().toIso8601String(),
        if (clockOutAt != null)
          'clock_out_at': clockOutAt!.toUtc().toIso8601String(),
        'reason': reason,
      };
}
