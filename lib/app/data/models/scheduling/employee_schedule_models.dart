import 'scheduling_date_utils.dart';

class EmployeeScheduleCreateRequest {
  const EmployeeScheduleCreateRequest({
    required this.employeeId,
    required this.templateId,
    required this.startDate,
    this.endDate,
  });

  final String employeeId;
  final String templateId;
  final DateTime startDate;
  final DateTime? endDate;

  Map<String, dynamic> toJson() => {
        'employee_id': employeeId,
        'template_id': templateId,
        'start_date': fmtSchedulingDate(startDate),
        'end_date': endDate != null ? fmtSchedulingDate(endDate!) : null,
      };
}

class EmployeeSchedulePatchRequest {
  const EmployeeSchedulePatchRequest({
    this.templateId,
    this.startDate,
    this.endDate,
  });

  final String? templateId;
  final DateTime? startDate;
  final DateTime? endDate;

  Map<String, dynamic> toJson() => {
        if (templateId != null) 'template_id': templateId,
        if (startDate != null) 'start_date': fmtSchedulingDate(startDate!),
        if (endDate != null) 'end_date': fmtSchedulingDate(endDate!),
      };
}

class EmployeeScheduleOut {
  const EmployeeScheduleOut({
    required this.id,
    required this.employeeId,
    required this.templateId,
    required this.startDate,
    this.endDate,
  });

  final String id;
  final String employeeId;
  final String templateId;
  final DateTime startDate;
  final DateTime? endDate;

  factory EmployeeScheduleOut.fromJson(Map<String, dynamic> json) {
    return EmployeeScheduleOut(
      id: json['id'] as String? ?? '',
      employeeId: json['employee_id'] as String? ?? '',
      templateId: json['template_id'] as String? ?? '',
      startDate: parseSchedulingDate(json['start_date'] as String? ?? ''),
      endDate: parseSchedulingDateOrNull(json['end_date']),
    );
  }
}

class IdResponse {
  const IdResponse({required this.id});

  final String id;

  factory IdResponse.fromJson(Map<String, dynamic> json) {
    return IdResponse(id: json['id'] as String? ?? '');
  }
}
