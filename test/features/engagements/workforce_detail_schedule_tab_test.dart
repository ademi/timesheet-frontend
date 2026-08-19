import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/errors/app_failure.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/credentials/data/repositories/credentials_repository.dart';
import 'package:rostiq/features/engagements/controllers/workforce_controller.dart';
import 'package:rostiq/features/engagements/data/models/engagement_models.dart';
import 'package:rostiq/features/engagements/data/repositories/engagements_repository.dart';
import 'package:rostiq/features/engagements/views/workforce_detail_view.dart';
import 'package:rostiq/features/payroll/controllers/engagement_rate_bands_controller.dart';
import 'package:rostiq/features/payroll/data/repositories/payroll_repository.dart';
import 'package:rostiq/features/visits/data/models/visit_models.dart';
import 'package:rostiq/features/visits/data/repositories/visits_repository.dart';
import 'package:rostiq/shared/models/profile_photo_models.dart';

class _MockEngagementsRepository extends Mock
    implements EngagementsRepository {}

class _MockCredentialsRepository extends Mock
    implements CredentialsRepository {}

class _MockPayrollRepository extends Mock implements PayrollRepository {}

class _MockSessionService extends Mock implements SessionService {}

class _MockVisitsRepository extends Mock implements VisitsRepository {}

final _now = DateTime.utc(2026, 8, 18, 9);

final _engagement = EngagementOut(
  id: 'eng-1',
  tenantId: 'tenant-1',
  contractorId: 'contractor-1',
  contractorName: 'Demo Contractor',
  contractorEmail: 'contractor@demotenant.example',
  status: 'active',
  createdAt: _now,
  updatedAt: _now,
);

VisitOut _visit({
  required String id,
  required String title,
  required DateTime start,
  required String status,
}) {
  final end = start.add(const Duration(hours: 1));
  return VisitOut(
    id: id,
    tenantId: 'tenant-1',
    jobId: 'job-$id',
    contractorId: 'contractor-1',
    scheduledStart: start,
    scheduledEnd: end,
    status: status,
    source: 'manual',
    geofenceRadiusM: 100,
    geofenceMode: 'informational',
    paymentStatus: 'unpaid',
    createdAt: start,
    updatedAt: start,
    jobTitle: title,
  );
}

void main() {
  late _MockEngagementsRepository repository;
  late _MockCredentialsRepository credentials;
  late _MockPayrollRepository payroll;
  late _MockSessionService session;
  late _MockVisitsRepository visits;
  late WorkforceController controller;

  setUpAll(() {
    registerFallbackValue(_now);
  });

  setUp(() {
    Get.testMode = true;
    Get.reset();
    repository = _MockEngagementsRepository();
    credentials = _MockCredentialsRepository();
    payroll = _MockPayrollRepository();
    session = _MockSessionService();
    visits = _MockVisitsRepository();

    when(() => session.hasPermission(any())).thenReturn(true);
    when(() => repository.listTenantEngagements()).thenAnswer((_) async => []);
    when(() => repository.getContractorProfilePhoto(any())).thenAnswer(
      (_) async => const ProfilePhotoOut(hasPhoto: false),
    );
    when(() => repository.listAvailability(any())).thenAnswer((_) async => []);
    when(() => payroll.listRates(any())).thenAnswer((_) async => []);
    when(
      () => visits.listVisits(
        contractorId: any(named: 'contractorId'),
        from: any(named: 'from'),
        to: any(named: 'to'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => []);

    controller = WorkforceController(
      repository: repository,
      credentialsRepository: credentials,
      session: session,
      visits: visits,
    );
    controller.selected = _engagement;
    Get.put(
      EngagementRateBandsController(
        payroll: payroll,
        session: session,
      ),
    );
    Get.put(controller);
    controller.onInit();
  });

  tearDown(Get.reset);

  testWidgets(
    'Schedule tab shows full window visits and empty availability copy',
    (tester) async {
      final futureVisit = _visit(
        id: 'future',
        title: 'Future support session',
        start: _now.add(const Duration(days: 2)),
        status: 'scheduled',
      );
      final pastVisit = _visit(
        id: 'past',
        title: 'Completed support session',
        start: _now.subtract(const Duration(days: 3)),
        status: 'completed',
      );
      when(
        () => visits.listVisits(
          contractorId: any(named: 'contractorId'),
          from: any(named: 'from'),
          to: any(named: 'to'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [futureVisit, pastVisit]);

      Get.routing.args = _engagement;
      await tester.pumpWidget(
        const GetMaterialApp(home: WorkforceDetailView()),
      );

      await tester.tap(find.byKey(const ValueKey('contractor-detail-tab-3')));
      await tester.pumpAndSettle();

      expect(find.text('Timetable'), findsOneWidget);
      expect(find.text('Future support session'), findsOneWidget);
      expect(find.text('Completed support session'), findsOneWidget);
      expect(find.text('No weekly availability set.'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('contractor-detail-tab-2')));
      await tester.pumpAndSettle();

      expect(find.text('Future support session'), findsOneWidget);
      expect(find.text('Completed support session'), findsNothing);
    },
  );

  testWidgets(
    'availability 403 shows error and still lists visits',
    (tester) async {
      final futureVisit = _visit(
        id: 'future',
        title: 'Future support session',
        start: _now.add(const Duration(days: 2)),
        status: 'scheduled',
      );
      when(
        () => visits.listVisits(
          contractorId: any(named: 'contractorId'),
          from: any(named: 'from'),
          to: any(named: 'to'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [futureVisit]);
      when(() => repository.listAvailability(any())).thenThrow(
        const AppFailure(
          code: 'forbidden',
          message: 'Missing contractors.read permission.',
          presentation: AppFailurePresentation.inline,
          statusCode: 403,
        ),
      );

      Get.routing.args = _engagement;
      await tester.pumpWidget(
        const GetMaterialApp(home: WorkforceDetailView()),
      );

      await tester.tap(find.byKey(const ValueKey('contractor-detail-tab-3')));
      await tester.pumpAndSettle();

      expect(find.text('Missing contractors.read permission.'), findsOneWidget);
      expect(find.text('Future support session'), findsOneWidget);
    },
  );
}
