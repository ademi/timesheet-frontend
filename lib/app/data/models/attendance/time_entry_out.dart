class TimeEntryOut {
  const TimeEntryOut({
    required this.id,
    required this.employeeId,
    required this.clockInAt,
    this.clockOutAt,
    required this.status,
  });

  final String id;
  final String employeeId;
  final DateTime clockInAt;
  final DateTime? clockOutAt;
  final String status;

  factory TimeEntryOut.fromJson(Map<String, dynamic> json) {
    return TimeEntryOut(
      id: json['id'] as String? ?? '',
      employeeId: json['employee_id'] as String? ?? '',
      clockInAt: DateTime.parse(json['clock_in_at'] as String),
      clockOutAt: json['clock_out_at'] != null
          ? DateTime.parse(json['clock_out_at'] as String)
          : null,
      status: json['status'] as String? ?? '',
    );
  }
}
