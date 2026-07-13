class BoardMeta {
  const BoardMeta({
    required this.assignedCount,
    required this.unassignedCount,
    required this.onLeaveCount,
    required this.dayOffCount,
    required this.conflictCount,
  });

  final int assignedCount;
  final int unassignedCount;
  final int onLeaveCount;
  final int dayOffCount;
  final int conflictCount;

  factory BoardMeta.fromJson(Map<String, dynamic> json) {
    return BoardMeta(
      assignedCount: json['assigned_count'] as int? ?? 0,
      unassignedCount: json['unassigned_count'] as int? ?? 0,
      onLeaveCount: json['on_leave_count'] as int? ?? 0,
      dayOffCount: json['day_off_count'] as int? ?? 0,
      conflictCount: json['conflict_count'] as int? ?? 0,
    );
  }
}
