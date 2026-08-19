import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/payroll/controllers/staff_payments_controller.dart';
import 'package:rostiq/features/payroll/data/models/payroll_models.dart';
import 'package:rostiq/features/payroll/data/repositories/payroll_repository.dart';
import 'package:rostiq/features/visits/data/models/visit_models.dart';
import 'package:rostiq/features/visits/data/repositories/visits_repository.dart';

class _MockPayrollRepository extends Mock implements PayrollRepository {}

class _MockVisitsRepository extends Mock implements VisitsRepository {}

class _MockSessionService extends Mock implements SessionService {}

void main() {
  late StaffPaymentsController controller;
  late _MockPayrollRepository payroll;
  late _MockVisitsRepository visits;

  setUp(() {
    Get.testMode = true;
    Get.reset();
    payroll = _MockPayrollRepository();
    visits = _MockVisitsRepository();
    final session = _MockSessionService();
    when(() => session.hasPermission(any())).thenReturn(true);
    when(() => payroll.listBatches(status: any(named: 'status')))
        .thenAnswer((_) async => <PaymentBatchOut>[]);
    when(
      () => visits.listVisits(
        from: any(named: 'from'),
        to: any(named: 'to'),
        status: any(named: 'status'),
        paymentStatus: any(named: 'paymentStatus'),
      ),
    ).thenAnswer((_) async => <VisitOut>[]);
    controller = StaffPaymentsController(
      payroll: payroll,
      visits: visits,
      session: session,
    );
    controller.onInit();
  });

  tearDown(Get.reset);

  test('createBatch without completed visits shows completed-visit error',
      () async {
    await controller.createBatch();
    expect(
      controller.errorMessage.value,
      'Visit must be completed to add to payment batch.',
    );
  });
}
