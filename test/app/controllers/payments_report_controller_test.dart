import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yemen_gate_attendance_app/app/controllers/payments_report_controller.dart';
import 'package:yemen_gate_attendance_app/app/data/models/attendance/employee_model.dart';
import 'package:yemen_gate_attendance_app/app/data/models/payment/payment_report_row.dart';
import 'package:yemen_gate_attendance_app/app/data/repositories/payment_repository.dart';
import 'package:yemen_gate_attendance_app/app/data/repositories/payroll_repository.dart';

class MockPaymentRepository extends Mock implements PaymentRepository {}

class MockPayrollRepository extends Mock implements PayrollRepository {}

void main() {
  late MockPaymentRepository paymentRepository;
  late MockPayrollRepository payrollRepository;
  late PaymentsReportController controller;

  setUp(() {
    Get.testMode = true;
    paymentRepository = MockPaymentRepository();
    payrollRepository = MockPayrollRepository();
    when(() => paymentRepository.getEmployees(branchId: any(named: 'branchId')))
        .thenAnswer((_) async => <EmployeeModel>[]);
    when(() => payrollRepository.getPeriods()).thenAnswer((_) async => []);
    when(
      () => paymentRepository.getPaymentsReport(
        from: any(named: 'from'),
        to: any(named: 'to'),
        employeeId: any(named: 'employeeId'),
        branchId: any(named: 'branchId'),
        periodId: any(named: 'periodId'),
      ),
    ).thenAnswer(
      (_) async => const [
        PaymentReportRow(
          paymentId: 'p-1',
          paymentDate: '2026-05-09',
          amountPaid: 120,
          currencyCode: 'USD',
          paymentMethod: 'cash',
          createdAt: '2026-05-09T10:00:00Z',
          employeeId: 'e-1',
          employeeCode: 'EMP-001',
          employeeName: 'Ahmed',
        ),
      ],
    );
    controller = PaymentsReportController(
      paymentRepository: paymentRepository,
      payrollRepository: payrollRepository,
    );
  });

  tearDown(Get.reset);

  test('fetchReport updates reactive rows and loading state', () async {
    controller.fromDate.value = DateTime(2026, 5, 1);
    controller.toDate.value = DateTime(2026, 5, 31);

    final future = controller.fetchReport();
    expect(controller.isLoading.value, isTrue);
    await future;

    expect(controller.isLoading.value, isFalse);
    expect(controller.rows, hasLength(1));
    expect(controller.rows.first.employeeName, 'Ahmed');
  });
}
