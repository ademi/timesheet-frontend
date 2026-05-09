import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yemen_gate_attendance_app/app/controllers/payments_report_controller.dart';
import 'package:yemen_gate_attendance_app/app/data/models/attendance/employee_model.dart';
import 'package:yemen_gate_attendance_app/app/data/models/payment/payment_report_row.dart';
import 'package:yemen_gate_attendance_app/app/data/repositories/payment_repository.dart';

class MockPaymentRepository extends Mock implements PaymentRepository {}

void main() {
  late MockPaymentRepository repository;
  late PaymentsReportController controller;

  setUp(() {
    Get.testMode = true;
    repository = MockPaymentRepository();
    when(() => repository.getEmployees(branchId: any(named: 'branchId')))
        .thenAnswer((_) async => <EmployeeModel>[]);
    when(
      () => repository.getPaymentsReport(
        from: any(named: 'from'),
        to: any(named: 'to'),
        employeeId: any(named: 'employeeId'),
        branchId: any(named: 'branchId'),
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
    controller = PaymentsReportController(repository: repository);
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
