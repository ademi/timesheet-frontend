class TimeEntryOut {
  const TimeEntryOut({
    required this.id,
    required this.employeeId,
    required this.clockInAt,
    this.clockOutAt,
    required this.status,
    this.clockInSource,
    this.clockOutSource,
    this.anomalyFlag = false,
  });

  final String id;
  final String employeeId;
  final DateTime clockInAt;
  final DateTime? clockOutAt;
  final String status;
  final String? clockInSource;
  final String? clockOutSource;
  final bool anomalyFlag;

  factory TimeEntryOut.fromJson(Map<String, dynamic> json) {
    return TimeEntryOut(
      id: json['id'] as String? ?? '',
      employeeId: json['employee_id'] as String? ?? '',
      clockInAt: DateTime.parse(json['clock_in_at'] as String),
      clockOutAt: json['clock_out_at'] != null
          ? DateTime.parse(json['clock_out_at'] as String)
          : null,
      status: json['status'] as String? ?? '',
      clockInSource: json['clock_in_source'] as String?,
      clockOutSource: json['clock_out_source'] as String?,
      anomalyFlag: json['anomaly_flag'] as bool? ?? false,
    );
  }
}
