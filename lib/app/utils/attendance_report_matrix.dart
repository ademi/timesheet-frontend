import '../data/models/attendance_report_model.dart';

/// Transposed attendance grid: dates as rows, employees as columns.
class AttendanceReportMatrix {
  AttendanceReportMatrix(this.reports);

  final List<AttendanceReportModel> reports;

  List<String> get employees =>
      reports.map((report) => report.employeeName).toList();

  List<String> get dates {
    final dateSet = <String>{};
    for (final report in reports) {
      for (final record in report.dailyRecords) {
        dateSet.add(record.date);
      }
    }
    final sorted = dateSet.toList()..sort();
    return sorted;
  }

  double hoursFor(String date, String employeeName) {
    for (final report in reports) {
      if (report.employeeName != employeeName) continue;
      for (final record in report.dailyRecords) {
        if (record.date == date) return record.hours.toDouble();
      }
      return 0;
    }
    return 0;
  }

  double totalForDate(String date) {
    var sum = 0.0;
    for (final employee in employees) {
      sum += hoursFor(date, employee);
    }
    return sum;
  }
}
