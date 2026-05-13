import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yemen_gate_attendance_app/app/controllers/create_payment_controller.dart';
import 'package:yemen_gate_attendance_app/app/data/models/attendance/employee_model.dart';
import 'package:yemen_gate_attendance_app/app/data/models/payment/create_payment_request.dart';
import 'package:yemen_gate_attendance_app/app/data/models/payment/payment_out.dart';
import 'package:yemen_gate_attendance_app/app/data/repositories/payment_repository.dart';
import 'package:yemen_gate_attendance_app/app/views/create_payment_view.dart';

class MockPaymentRepository extends Mock implements PaymentRepository {}

void main() {
  late MockPaymentRepository repository;

  setUpAll(() {
    registerFallbackValue(
      const CreatePaymentRequest(
        employeeId: 'emp',
        paymentDate: '2026-01-01',
        amountPaid: 0,
        currencyCode: 'USD',
      ),
    );
  });

  setUp(() {
    Get.testMode = true;
    repository = MockPaymentRepository();
    when(() => repository.getEmployees(branchId: any(named: 'branchId'))).thenAnswer(
      (_) async => const [
        EmployeeModel(
          id: 'emp-1',
          tenantId: 'tenant-1',
          branchId: 'branch-1',
          userId: 'user-1',
          employeeCode: 'EMP-001',
          fullName: 'Ahmed Ali',
          phone: '123',
          email: 'ahmed@example.com',
          dob: '1990-01-01',
          isActive: true,
          clockedIn: false,
          clockedOut: false,
        ),
      ],
    );
    when(() => repository.createPayment(any())).thenAnswer(
      (_) async => const PaymentOut(
        id: 'p-1',
        tenantId: 'tenant-1',
        employeeId: 'emp-1',
        paymentDate: '2026-05-09',
        amountPaid: 100,
        currencyCode: 'USD',
        createdAt: '2026-05-09T10:00:00Z',
        updatedAt: '2026-05-09T10:00:00Z',
      ),
    );
  });

  tearDown(Get.reset);

  testWidgets('CreatePaymentView validates required amount field', (tester) async {
    Get.put(CreatePaymentController(repository: repository));
    await tester.pumpWidget(
      const GetMaterialApp(home: CreatePaymentView()),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('create_payment_submit_button')));
    await tester.tap(find.byKey(const Key('create_payment_submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('Amount is required'), findsOneWidget);
  });
}
