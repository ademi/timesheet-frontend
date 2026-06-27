import 'board_day.dart';

class BoardEmployee {
  const BoardEmployee({
    required this.employeeId,
    required this.fullName,
    required this.employeeCode,
    this.branchId,
    required this.isActive,
    required this.days,
  });

  final String employeeId;
  final String fullName;
  final String employeeCode;
  final String? branchId;
  final bool isActive;
  final List<BoardDay> days;

  factory BoardEmployee.fromJson(Map<String, dynamic> json) {
    return BoardEmployee(
      employeeId: json['employee_id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      employeeCode: json['employee_code'] as String? ?? '',
      branchId: json['branch_id'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      days: (json['days'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(BoardDay.fromJson)
          .toList(),
    );
  }
}
