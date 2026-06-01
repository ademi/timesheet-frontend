import 'package:data_table_2/data_table_2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yemen_gate_attendance_app/app/controllers/payments_report_controller.dart';
import 'package:yemen_gate_attendance_app/app/data/models/attendance/employee_model.dart';
import 'package:yemen_gate_attendance_app/app/data/models/payment/payment_report_row.dart';
import 'package:yemen_gate_attendance_app/app/data/repositories/payment_repository.dart';
import 'package:yemen_gate_attendance_app/app/data/repositories/payroll_repository.dart';
import 'package:yemen_gate_attendance_app/app/views/payments_report_view.dart';
import 'package:yemen_gate_attendance_app/core/services/token_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MockPaymentRepository extends Mock implements PaymentRepository {}

class MockPayrollRepository extends Mock implements PayrollRepository {}

void main() {
  late MockPaymentRepository paymentRepository;
  late MockPayrollRepository payrollRepository;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    Get.testMode = true;
    Get.put<TokenStorage>(TokenStorage(), permanent: true);
    paymentRepository = MockPaymentRepository();
    payrollRepository = MockPayrollRepository();
    when(() => paymentRepository.getEmployees(branchId: any(named: 'branchId')))
        .thenAnswer((_) async => <EmployeeModel>[]);
    when(() => payrollRepository.getPeriods()).thenAnswer((_) async => []);
  });

  tearDown(Get.reset);

  testWidgets('PaymentsReportView renders DataTable2 when rows exist', (tester) async {
    final controller = Get.put(
      PaymentsReportController(
        paymentRepository: paymentRepository,
        payrollRepository: payrollRepository,
      ),
    );
    controller.rows.assignAll(
      const [
        PaymentReportRow(
          paymentId: 'p-1',
          paymentDate: '2026-05-09',
          amountPaid: 300,
          currencyCode: 'USD',
          paymentMethod: 'cash',
          referenceNo: 'REF-1',
          createdAt: '2026-05-09T10:00:00Z',
          employeeId: 'e-1',
          employeeCode: 'EMP-001',
          employeeName: 'Ahmed',
        ),
      ],
    );

    await tester.pumpWidget(const GetMaterialApp(home: PaymentsReportView()));
    await tester.pumpAndSettle();

    expect(find.byType(DataTable2), findsOneWidget);
  });
}
