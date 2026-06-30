import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/controllers/employee_rate_form_controller.dart';
import 'package:rostiq/app/data/models/payroll/rate_create_request.dart';
import 'package:rostiq/app/data/models/payroll/rate_out.dart';
import 'package:rostiq/app/data/repositories/payroll_repository.dart';
import 'package:rostiq/app/routes/route_args.dart';

class MockPayrollRepository extends Mock implements PayrollRepository {}

void main() {
  late MockPayrollRepository repository;
  late EmployeeRateFormController controller;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(
      RateCreateRequest(
        effectiveFrom: DateTime(2026, 5, 1),
        baseRate: 1,
        weekendRate: 1,
        nightRate: 1,
      ),
    );
  });

  setUp(() {
    Get.testMode = true;
    repository = MockPayrollRepository();
    when(() => repository.createRate(any(), any())).thenAnswer((_) async => RateOut(
          id: 'r1',
          tenantId: 't1',
          employeeId: 'emp-1',
          effectiveFrom: DateTime(2026, 5, 1),
          baseRate: 25,
          weekendRate: 25,
          nightRate: 25,
          overtimeRate: 25,
          nightShiftStart: '22:00',
          nightShiftEnd: '06:00',
          createdAt: DateTime(2026, 5, 1),
          updatedAt: DateTime(2026, 5, 1),
        ));

    controller = EmployeeRateFormController(repository: repository);
    controller.bindFromArgs(const EmployeeRateFormArgs(employeeId: 'emp-1'));
  });

  tearDown(() {
    controller.onClose();
    Get.reset();
  });

  group('EmployeeRateFormController', () {
    test('applyBaseRateToDerivedRates copies base into empty rate fields only', () {
      controller.baseRateController.text = '42.5';
      controller.weekendRateController.text = '10';
      controller.applyBaseRateToDerivedRates();

      expect(controller.weekendRateController.text, '10');
      expect(controller.nightRateController.text, '42.5');
      expect(controller.overtimeRateController.text, '42.5');
    });

    test('applyBaseRateToDerivedRates fills all when empty', () {
      controller.baseRateController.text = '42.5';
      controller.applyBaseRateToDerivedRates();

      expect(controller.weekendRateController.text, '42.5');
      expect(controller.nightRateController.text, '42.5');
      expect(controller.overtimeRateController.text, '42.5');
    });

    test('submit sends null OT thresholds when fields are empty', () async {
      await Get.to(() => const SizedBox.shrink());

      controller.effectiveFrom.value = DateTime(2026, 5, 1);
      controller.baseRateController.text = '30';
      controller.weekendRateController.text = '30';
      controller.nightRateController.text = '30';
      controller.overtimeRateController.text = '30';
      controller.dailyThresholdController.text = '';
      controller.weeklyThresholdController.text = '';

      await controller.submit();

      final captured = verify(() => repository.createRate('emp-1', captureAny())).captured.single
          as RateCreateRequest;
      expect(captured.overtimeDailyThresholdMinutes, isNull);
      expect(captured.overtimeWeeklyThresholdMinutes, isNull);
    });
  });
}
