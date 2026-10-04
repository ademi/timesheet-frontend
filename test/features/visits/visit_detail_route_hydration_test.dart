import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/routes/app_routes.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/engagements/data/repositories/engagements_repository.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';
import 'package:rostiq/features/shifts/data/models/shift_models.dart';
import 'package:rostiq/features/shifts/data/repositories/shifts_repository.dart';
import 'package:rostiq/features/visits/controllers/staff_visits_controller.dart';
import 'package:rostiq/features/visits/data/models/visit_models.dart';
import 'package:rostiq/features/visits/data/repositories/visits_repository.dart';

class _MockVisitsRepository extends Mock implements VisitsRepository {}

class _MockShiftsRepository extends Mock implements ShiftsRepository {}

class _MockJobsRepository extends Mock implements JobsRepository {}

class _MockEngagementsRepository extends Mock
    implements EngagementsRepository {}

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _MockSessionService extends Mock implements SessionService {}

final _now = DateTime.utc(2026, 9, 27, 9);

final _visit = VisitOut(
  id: 'visit-1',
  tenantId: 'tenant-1',
  jobId: 'job-1',
  contractorId: 'contractor-1',
  scheduledStart: _now,
  scheduledEnd: _now.add(const Duration(hours: 2)),
  status: 'scheduled',
  source: 'roster',
  geofenceRadiusM: 100,
  geofenceMode: 'soft',
  paymentStatus: 'pending',
  createdAt: _now,
  updatedAt: _now,
  jobTitle: 'Support',
);

final _shift = ShiftOut(
  id: 'shift-1',
  tenantId: 'tenant-1',
  jobId: 'job-1',
  jobTitle: 'Group',
  scheduledStart: _now,
  scheduledEnd: _now.add(const Duration(hours: 4)),
  requiredSlots: 2,
  openSlots: 2,
  status: 'draft',
  createdAt: _now,
  updatedAt: _now,
);

void main() {
  late _MockVisitsRepository visits;
  late _MockShiftsRepository shifts;
  late _MockSessionService session;
  late StaffVisitsController controller;

  setUp(() {
    Get.testMode = true;
    Get.reset();
    visits = _MockVisitsRepository();
    shifts = _MockShiftsRepository();
    session = _MockSessionService();
    when(() => session.hasPermission(any())).thenReturn(true);
    when(() => visits.getVisit(_visit.id)).thenAnswer((_) async => _visit);
    when(
      () => shifts.getShift(_shift.id, includeTravel: any(named: 'includeTravel')),
    ).thenAnswer((_) async => _shift);
    when(() => shifts.getShift(_shift.id)).thenAnswer((_) async => _shift);
    controller = StaffVisitsController(
      repository: visits,
      shiftsRepository: shifts,
      jobsRepository: _MockJobsRepository(),
      engagementsRepository: _MockEngagementsRepository(),
      clientsRepository: _MockClientsRepository(),
      session: session,
    );
    Get.put(controller);
  });

  tearDown(Get.reset);

  test('refreshSelected hydrates visit from route id param', () async {
    Get.parameters['id'] = _visit.id;
    Get.routing.args = null;
    controller.selected.value = null;

    await controller.refreshSelected();

    expect(controller.selected.value?.id, _visit.id);
    verify(() => visits.getVisit(_visit.id)).called(1);
  });

  test('refreshSelectedShift hydrates shift from route id param', () async {
    Get.parameters['id'] = _shift.id;
    Get.routing.args = null;
    controller.selectedShift.value = null;

    await controller.refreshSelectedShift();

    expect(controller.selectedShift.value?.id, _shift.id);
  });

  testWidgets('openDetail passes visit id in route parameters', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: AppRoutes.staffVisits,
        getPages: [
          GetPage(
            name: AppRoutes.staffVisits,
            page: () => const SizedBox.shrink(),
          ),
          GetPage(
            name: AppRoutes.staffVisitDetail,
            page: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );

    await controller.openDetail(_visit);
    await tester.pumpAndSettle();

    expect(Get.currentRoute.startsWith(AppRoutes.staffVisitDetail), isTrue);
    expect(Get.parameters['id'], _visit.id);
  });
}
