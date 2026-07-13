import 'shift_source.dart';
import 'shift_status.dart';
import 'scheduling_date_utils.dart';

class BoardDay {
  const BoardDay({
    required this.date,
    required this.status,
    this.source,
    this.templateId,
    this.templateName,
    this.shiftStart,
    this.shiftEnd,
    required this.conflicts,
    required this.isWorkingToday,
    this.clockedIn,
    this.isLate,
  });

  final DateTime date;
  final ShiftStatus status;
  final ShiftSource? source;
  final String? templateId;
  final String? templateName;
  final String? shiftStart;
  final String? shiftEnd;
  final List<String> conflicts;
  final bool isWorkingToday;
  final bool? clockedIn;
  final bool? isLate;

  factory BoardDay.fromJson(Map<String, dynamic> json) {
    return BoardDay(
      date: parseSchedulingDate(json['date'] as String? ?? ''),
      status: ShiftStatus.fromApiValue(json['status'] as String?),
      source: ShiftSource.fromApiValue(json['source'] as String?),
      templateId: json['template_id'] as String?,
      templateName: json['template_name'] as String?,
      shiftStart: json['shift_start'] as String?,
      shiftEnd: json['shift_end'] as String?,
      conflicts: List<String>.from(json['conflicts'] as List? ?? []),
      isWorkingToday: json['is_working_today'] as bool? ?? false,
      clockedIn: json['clocked_in'] as bool?,
      isLate: json['is_late'] as bool?,
    );
  }
}
