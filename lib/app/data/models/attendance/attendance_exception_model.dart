/// A single row in the admin attendance review queue returned by
/// `GET /v1/attendance/exceptions`.
class AttendanceExceptionModel {
  const AttendanceExceptionModel({
    required this.id,
    required this.employeeId,
    this.clockInAt,
    this.clockOutAt,
    required this.status,
    this.clockInSource,
    this.clockOutSource,
    this.anomalyFlag = false,
    required this.exceptionType,
  });

  /// Time entry id (when one exists). May be empty for exceptions that have no
  /// backing time entry yet.
  final String id;
  final String employeeId;
  final DateTime? clockInAt;
  final DateTime? clockOutAt;
  final String status;
  final String? clockInSource;
  final String? clockOutSource;
  final bool anomalyFlag;

  /// One of: missing_clock_out, manual_adjustment, long_shift, needs_review.
  final String exceptionType;

  bool get hasOpenEntry => id.isNotEmpty;

  factory AttendanceExceptionModel.fromJson(Map<String, dynamic> json) {
    return AttendanceExceptionModel(
      id: json['id'] as String? ?? '',
      employeeId: json['employee_id'] as String? ?? '',
      clockInAt: json['clock_in_at'] != null
          ? DateTime.tryParse(json['clock_in_at'] as String)
          : null,
      clockOutAt: json['clock_out_at'] != null
          ? DateTime.tryParse(json['clock_out_at'] as String)
          : null,
      status: json['status'] as String? ?? '',
      clockInSource: json['clock_in_source'] as String?,
      clockOutSource: json['clock_out_source'] as String?,
      anomalyFlag: json['anomaly_flag'] as bool? ?? false,
      exceptionType: json['exception_type'] as String? ?? 'needs_review',
    );
  }
}
