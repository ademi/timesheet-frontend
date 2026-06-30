import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/app/data/models/attendance_report_model.dart';
import 'package:rostiq/app/utils/attendance_report_matrix.dart';

void main() {
  group('AttendanceReportMatrix', () {
    final reports = [
      AttendanceReportModel(
        employeeId: 'e1',
        employeeName: 'Alice',
        dailyRecords: [
          DailyRecord(date: '2026-05-01', hours: 8),
          DailyRecord(date: '2026-05-02', hours: 6),
        ],
        total: ReportTotal(days: 2, hours: 14),
      ),
      AttendanceReportModel(
        employeeId: 'e2',
        employeeName: 'Bob',
        dailyRecords: [
          DailyRecord(date: '2026-05-01', hours: 7),
        ],
        total: ReportTotal(days: 1, hours: 7),
      ),
    ];

    test('lists sorted dates as rows and employees as columns', () {
      final matrix = AttendanceReportMatrix(reports);

      expect(matrix.dates, ['2026-05-01', '2026-05-02']);
      expect(matrix.employees, ['Alice', 'Bob']);
    });

    test('hoursFor returns zero when employee has no record on date', () {
      final matrix = AttendanceReportMatrix(reports);

      expect(matrix.hoursFor('2026-05-01', 'Alice'), 8);
      expect(matrix.hoursFor('2026-05-02', 'Bob'), 0);
    });

    test('totalForDate sums hours across employees', () {
      final matrix = AttendanceReportMatrix(reports);

      expect(matrix.totalForDate('2026-05-01'), 15);
      expect(matrix.totalForDate('2026-05-02'), 6);
    });
  });
}
