import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yemen_gate_attendance_app/app/controllers/employee_detail_controller.dart';
import 'package:yemen_gate_attendance_app/app/data/models/attendance/employee_model.dart';
import 'package:yemen_gate_attendance_app/app/data/models/attendance/employee_update_request.dart';
import 'package:yemen_gate_attendance_app/app/data/models/payroll/employee_balance_out.dart';
import 'package:yemen_gate_attendance_app/app/data/repositories/employee_repository.dart';
import 'package:yemen_gate_attendance_app/app/data/repositories/payroll_repository.dart';

class MockEmployeeRepository extends Mock implements EmployeeRepository {}

class MockPayrollRepository extends Mock implements PayrollRepository {}

void main() {
  late MockEmployeeRepository employeeRepository;
  late MockPayrollRepository payrollRepository;
  late EmployeeDetailController controller;

  const employee = EmployeeModel(
    id: 'emp-1',
    tenantId: 'tenant-1',
    branchId: 'branch-1',
    userId: 'user-1',
    employeeCode: 'EMP-001',
    fullName: 'Ahmed Ali',
    phone: '700000',
    email: 'ahmed@example.com',
    dob: '1990-01-01',
    isActive: true,
    clockedIn: false,
    clockedOut: false,
    defaultCurrencyCode: 'NZD',
  );

  setUpAll(() {
    registerFallbackValue(
      const EmployeeUpdateRequest(fullName: 'x'),
    );
  });

  setUp(() {
    Get.testMode = true;
    employeeRepository = MockEmployeeRepository();
    payrollRepository = MockPayrollRepository();

    when(() => employeeRepository.getEmployee(any())).thenAnswer((_) async => employee);
    when(() => payrollRepository.getPeriods()).thenAnswer((_) async => []);
    when(() => payrollRepository.getRates(any())).thenAnswer((_) async => []);
    when(() => payrollRepository.getEmployeeBalance(any())).thenAnswer(
      (_) async => const EmployeeBalanceOut(
        employeeId: 'emp-1',
        totalOwed: 0,
        totalPaid: 0,
        outstanding: 0,
        currencyCode: 'AUD',
      ),
    );
    when(() => employeeRepository.listRoleOptions()).thenAnswer((_) async => []);

    controller = EmployeeDetailController(
      employeeRepository: employeeRepository,
      payrollRepository: payrollRepository,
    );
    controller.bindEmployeeId('emp-1');
  });

  tearDown(() {
    controller.onClose();
    Get.reset();
  });

  group('EmployeeDetailController', () {
    test('starts with editing disabled', () {
      expect(controller.isEditing.value, isFalse);
    });

    test('startEditing enables edit mode', () async {
      await controller.startEditing();
      expect(controller.isEditing.value, isTrue);
    });

    test('cancelEditing restores form from employee and disables edit mode', () async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      controller.startEditing();
      controller.fullNameController.text = 'Changed Name';
      controller.defaultCurrencyCode.value = 'USD';

      controller.cancelEditing();

      expect(controller.isEditing.value, isFalse);
      expect(controller.fullNameController.text, 'Ahmed Ali');
      expect(controller.defaultCurrencyCode.value, 'NZD');
    });
  });
}
