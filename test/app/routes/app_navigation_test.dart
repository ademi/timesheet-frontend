import 'package:flutter_test/flutter_test.dart';
import 'package:yemen_gate_attendance_app/app/data/models/attendance/employee_model.dart';
import 'package:yemen_gate_attendance_app/app/routes/app_navigation.dart';
import 'package:yemen_gate_attendance_app/app/routes/route_args.dart';

void main() {
  group('readBoolResult', () {
    test('returns true only for literal true', () {
      expect(readBoolResult(true), isTrue);
      expect(readBoolResult(false), isFalse);
      expect(readBoolResult(null), isFalse);
      expect(readBoolResult(1), isFalse);
    });
  });

  group('readTypedResult', () {
    test('returns value when type matches', () {
      const employee = EmployeeModel(
        id: 'e1',
        tenantId: 't1',
        branchId: 'b1',
        userId: 'u1',
        employeeCode: 'E1',
        fullName: 'Test',
        phone: '1',
        email: 't@t.com',
        dob: '2000-01-01',
        isActive: true,
        clockedIn: false,
        clockedOut: false,
      );
      const pickerResult = EmployeePickerResult(employee);
      expect(readTypedResult<EmployeePickerResult>(pickerResult), pickerResult);
    });

    test('returns null when type does not match', () {
      expect(readTypedResult<EmployeePickerResult>('wrong'), isNull);
    });
  });
}
