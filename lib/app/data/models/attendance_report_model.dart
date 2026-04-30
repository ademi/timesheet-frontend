class AttendanceReportModel {
  final String employeeId;
  final String employeeName;
  final List<DailyRecord> dailyRecords;
  final ReportTotal total;

  AttendanceReportModel({
    required this.employeeId,
    required this.employeeName,
    required this.dailyRecords,
    required this.total,
  });

  factory AttendanceReportModel.fromJson(Map<String, dynamic> json) {
    return AttendanceReportModel(
      employeeId: json['employee_id'] as String,
      employeeName: json['employee_name'] as String,
      dailyRecords: (json['daily_records'] as List<dynamic>?)
              ?.map((e) => DailyRecord.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      total: json['total'] != null
          ? ReportTotal.fromJson(json['total'] as Map<String, dynamic>)
          : ReportTotal(days: 0, hours: 0.0),
    );
  }
}

class DailyRecord {
  final String date;
  final num hours;

  DailyRecord({
    required this.date,
    required this.hours,
  });

  factory DailyRecord.fromJson(Map<String, dynamic> json) {
    return DailyRecord(
      date: json['date'] as String,
      hours: json['hours'] as num? ?? 0,
    );
  }
}

class ReportTotal {
  final int days;
  final num hours;

  ReportTotal({
    required this.days,
    required this.hours,
  });

  factory ReportTotal.fromJson(Map<String, dynamic> json) {
    return ReportTotal(
      days: json['days'] as int? ?? 0,
      hours: json['hours'] as num? ?? 0,
    );
  }
}
