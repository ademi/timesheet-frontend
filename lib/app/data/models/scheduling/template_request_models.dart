class TemplateCreateRequest {
  const TemplateCreateRequest({
    required this.name,
    required this.shiftStart,
    required this.shiftEnd,
    this.breakMinutesDefault = 0,
    this.color,
    this.sortOrder = 0,
    this.branchId,
  });

  final String name;
  final String shiftStart;
  final String shiftEnd;
  final int breakMinutesDefault;
  final String? color;
  final int sortOrder;
  final String? branchId;

  Map<String, dynamic> toJson() => {
        'name': name,
        'shift_start': shiftStart,
        'shift_end': shiftEnd,
        'break_minutes_default': breakMinutesDefault,
        if (color != null) 'color': color,
        'sort_order': sortOrder,
        if (branchId != null && branchId!.isNotEmpty) 'branch_id': branchId,
      };
}

class TemplatePatchRequest {
  const TemplatePatchRequest({
    this.name,
    this.shiftStart,
    this.shiftEnd,
    this.breakMinutesDefault,
    this.color,
    this.sortOrder,
    this.isActive,
  });

  final String? name;
  final String? shiftStart;
  final String? shiftEnd;
  final int? breakMinutesDefault;
  final String? color;
  final int? sortOrder;
  final bool? isActive;

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (shiftStart != null) 'shift_start': shiftStart,
        if (shiftEnd != null) 'shift_end': shiftEnd,
        if (breakMinutesDefault != null)
          'break_minutes_default': breakMinutesDefault,
        if (color != null) 'color': color,
        if (sortOrder != null) 'sort_order': sortOrder,
        if (isActive != null) 'is_active': isActive,
      };
}
