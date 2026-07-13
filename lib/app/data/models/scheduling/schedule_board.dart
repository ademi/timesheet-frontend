import 'board_employee.dart';
import 'board_meta.dart';
import 'schedule_template.dart';
import 'scheduling_date_utils.dart';

class ScheduleBoard {
  const ScheduleBoard({
    required this.branchId,
    required this.startDate,
    required this.endDate,
    required this.templates,
    required this.employees,
    required this.meta,
  });

  final String branchId;
  final DateTime startDate;
  final DateTime endDate;
  final List<ScheduleTemplate> templates;
  final List<BoardEmployee> employees;
  final BoardMeta meta;

  factory ScheduleBoard.fromJson(Map<String, dynamic> json) {
    return ScheduleBoard(
      branchId: json['branch_id'] as String? ?? '',
      startDate: parseSchedulingDate(json['start_date'] as String? ?? ''),
      endDate: parseSchedulingDate(json['end_date'] as String? ?? ''),
      templates: (json['templates'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ScheduleTemplate.fromJson)
          .toList(),
      employees: (json['employees'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(BoardEmployee.fromJson)
          .toList(),
      meta: BoardMeta.fromJson(
        json['meta'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}
