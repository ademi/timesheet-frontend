/// Response from `POST /v1/attendance/adjustments`.
class AttendanceAdjustmentResponse {
  const AttendanceAdjustmentResponse({
    required this.adjustmentId,
    required this.timeEntryId,
    required this.status,
    this.createdAt,
  });

  final String adjustmentId;
  final String timeEntryId;
  final String status;
  final DateTime? createdAt;

  factory AttendanceAdjustmentResponse.fromJson(Map<String, dynamic> json) {
    return AttendanceAdjustmentResponse(
      adjustmentId: json['adjustment_id'] as String? ?? '',
      timeEntryId: json['time_entry_id'] as String? ?? '',
      status: json['status'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}
