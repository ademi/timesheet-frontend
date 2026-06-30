import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/app/data/models/payroll/rate_out.dart';
import 'package:rostiq/app/routes/route_args.dart';

void main() {
  const employeeId = 'emp-1';

  final sampleRate = RateOut(
    id: 'rate-1',
    tenantId: 'tenant-1',
    employeeId: employeeId,
    effectiveFrom: DateTime(2026, 5, 1),
    effectiveTo: null,
    baseRate: 10,
    weekendRate: 12,
    nightRate: 14,
    overtimeRate: 0,
    overtimeDailyThresholdMinutes: 480,
    overtimeWeeklyThresholdMinutes: 2400,
    nightShiftStart: '22:00',
    nightShiftEnd: '06:00',
    createdAt: DateTime(2026, 5, 1),
    updatedAt: DateTime(2026, 5, 1),
  );

  test('EmployeeRateFormArgs isEdit is false for create', () {
    const args = EmployeeRateFormArgs(employeeId: employeeId);
    expect(args.isEdit, isFalse);
    expect(args.rate, isNull);
    expect(args.finishCreateFlowOnSave, isFalse);
  });

  test('EmployeeRateFormArgs isEdit is true when rate is provided', () {
    final args = EmployeeRateFormArgs(employeeId: employeeId, rate: sampleRate);
    expect(args.isEdit, isTrue);
    expect(args.rate, sampleRate);
  });
}
