class VisitCheckInOut {
  const VisitCheckInOut({
    required this.visitId,
    required this.status,
    required this.timeEntryId,
  });

  final String visitId;
  final String status;
  final String timeEntryId;

  factory VisitCheckInOut.fromJson(Map<String, dynamic> json) {
    return VisitCheckInOut(
      visitId: json['visit_id'] as String,
      status: json['status'] as String,
      timeEntryId: json['time_entry_id'] as String,
    );
  }
}
