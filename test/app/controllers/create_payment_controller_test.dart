import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yemen_gate_attendance_app/app/controllers/create_payment_controller.dart';
import 'package:yemen_gate_attendance_app/app/data/models/attendance/employee_model.dart';
import 'package:yemen_gate_attendance_app/app/data/models/payment/create_payment_request.dart';
import 'package:yemen_gate_attendance_app/app/data/models/payment/payment_out.dart';
import 'package:yemen_gate_attendance_app/app/data/repositories/payment_repository.dart';

class MockPaymentRepository extends Mock implements PaymentRepository {}

void main() {
  late MockPaymentRepository repository;
  late CreatePaymentController controller;

  final employee = const EmployeeModel(
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
  );

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
      (_) async => [employee],
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

    controller = CreatePaymentController(repository: repository);
    controller.onInit();
  });

  tearDown(() {
    Get.reset();
  });

  group('CreatePaymentController', () {
    test('loads employees and updates reactive list', () async {
      await controller.loadEmployees();
      expect(controller.employees, hasLength(1));
      expect(controller.filteredEmployees.first.fullName, 'Ahmed Ali');
    });

    test('validateAmount enforces numeric and non-negative values', () {
      expect(controller.validateAmount(''), 'Amount is required');
      expect(controller.validateAmount('abc'), 'Enter a valid amount');
      expect(controller.validateAmount('-2'), 'Amount must be zero or more');
      expect(controller.validateAmount('12.5'), isNull);
    });

    test('submitPayment toggles loading state and calls repository', () async {
      final completer = Completer<PaymentOut>();
      when(() => repository.createPayment(any())).thenAnswer((_) => completer.future);

      controller.selectedEmployee.value = employee;
      controller.amountController.text = '250';
      controller.selectedCurrencyCode.value = 'USD';

      final future = controller.submitPayment();
      expect(controller.isLoading.value, isTrue);

      completer.complete(
        const PaymentOut(
          id: 'p-2',
          tenantId: 'tenant-1',
          employeeId: 'emp-1',
          paymentDate: '2026-05-09',
          amountPaid: 250,
          currencyCode: 'USD',
          createdAt: '2026-05-09T10:00:00Z',
          updatedAt: '2026-05-09T10:00:00Z',
        ),
      );
      await future;

      expect(controller.isLoading.value, isFalse);
      verify(() => repository.createPayment(any(that: isA<CreatePaymentRequest>()))).called(1);
    });
  });
}
