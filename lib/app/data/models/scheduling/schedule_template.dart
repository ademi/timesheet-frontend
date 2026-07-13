class ScheduleTemplate {
  const ScheduleTemplate({
    required this.id,
    required this.name,
    required this.shiftStart,
    required this.shiftEnd,
    required this.breakMinutesDefault,
    required this.isActive,
    this.branchId,
    this.color,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final String shiftStart;
  final String shiftEnd;
  final int breakMinutesDefault;
  final bool isActive;
  final String? branchId;
  final String? color;
  final int sortOrder;

  factory ScheduleTemplate.fromJson(Map<String, dynamic> json) {
    return ScheduleTemplate(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      shiftStart: json['shift_start'] as String? ?? '',
      shiftEnd: json['shift_end'] as String? ?? '',
      breakMinutesDefault: json['break_minutes_default'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      branchId: json['branch_id'] as String?,
      color: json['color'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }
}
