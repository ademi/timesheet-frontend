import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/credentials/data/repositories/credentials_repository.dart';
import 'package:rostiq/features/engagements/controllers/workforce_controller.dart';
import 'package:rostiq/features/engagements/data/models/engagement_models.dart';
import 'package:rostiq/features/engagements/data/repositories/engagements_repository.dart';
import 'package:rostiq/features/engagements/views/workforce_detail_view.dart';
import 'package:rostiq/features/payroll/controllers/engagement_rate_bands_controller.dart';
import 'package:rostiq/features/payroll/data/repositories/payroll_repository.dart';
import 'package:rostiq/shared/models/profile_photo_models.dart';

class _MockEngagementsRepository extends Mock
    implements EngagementsRepository {}

class _MockCredentialsRepository extends Mock
    implements CredentialsRepository {}

class _MockPayrollRepository extends Mock implements PayrollRepository {}

class _MockSessionService extends Mock implements SessionService {}

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

void main() {
  late _MockEngagementsRepository repository;
  late _MockCredentialsRepository credentials;
  late _MockPayrollRepository payroll;
  late _MockSessionService session;
  late WorkforceController controller;

  setUp(() {
    Get.testMode = true;
    Get.reset();
    repository = _MockEngagementsRepository();
    credentials = _MockCredentialsRepository();
    payroll = _MockPayrollRepository();
    session = _MockSessionService();
    when(() => session.hasPermission(any())).thenReturn(true);
    when(() => repository.getContractorProfilePhoto(any())).thenAnswer(
      (_) async => const ProfilePhotoOut(hasPhoto: false),
    );
    when(() => payroll.listRates(any())).thenAnswer((_) async => []);
    controller = WorkforceController(
      repository: repository,
      credentialsRepository: credentials,
      session: session,
    );
    Get.put(
      EngagementRateBandsController(
        payroll: payroll,
        session: session,
      ),
    );
    controller.selected = _engagement;
    Get.put(controller);
  });

  tearDown(Get.reset);

  testWidgets('shows subject tabs and Overview first', (tester) async {
    Get.routing.args = _engagement;
    await tester.pumpWidget(
      const GetMaterialApp(home: WorkforceDetailView()),
    );

    expect(find.byKey(const ValueKey('contractor-detail-tab-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('contractor-detail-tab-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('contractor-detail-tab-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('contractor-detail-tab-3')), findsOneWidget);
    expect(find.text('Overview'), findsWidgets);
    expect(find.text('Lifecycle'), findsOneWidget);
    expect(find.text('No upcoming visits.'), findsNothing);
  });
}
