import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/constants/app_permissions.dart';
import 'package:rostiq/features/contractor_onboarding/data/repositories/compliance_repository.dart';
import 'package:rostiq/features/credentials/controllers/credentials_controller.dart';
import 'package:rostiq/features/credentials/data/models/credential_models.dart';
import 'package:rostiq/features/credentials/data/repositories/credentials_repository.dart';
import 'package:rostiq/features/credentials/views/credential_missing_create_view.dart';
import 'package:rostiq/features/documents/data/document_pipeline.dart';
import 'package:rostiq/core/services/session_service.dart';

class _MockCredentialsRepository extends Mock
    implements CredentialsRepository {}

class _MockDocumentPipeline extends Mock implements DocumentPipeline {}

class _MockComplianceRepository extends Mock implements ComplianceRepository {}

class _MockSessionService extends Mock implements SessionService {}

void main() {
  late _MockCredentialsRepository repository;
  late _MockDocumentPipeline pipeline;
  late _MockComplianceRepository compliance;
  late _MockSessionService session;

  setUp(() {
    Get.testMode = true;
    clearCredentialCategoryLabelCache();
    repository = _MockCredentialsRepository();
    pipeline = _MockDocumentPipeline();
    compliance = _MockComplianceRepository();
    session = _MockSessionService();

    when(
      () => session.hasPermission(AppPermissions.credentialsRead),
    ).thenReturn(true);
    when(
      () => session.hasPermission(AppPermissions.credentialsManage),
    ).thenReturn(true);
    when(() => session.contractorId).thenReturn(RxnString('contractor-1'));
    when(() => session.claims).thenReturn(null);
    when(() => repository.listMine()).thenAnswer((_) async => []);
    when(
      () => repository.listCredentialCategories(),
    ).thenAnswer((_) async => []);
  });

  tearDown(Get.reset);

  testWidgets('renders one section per missing credential type', (tester) async {
    final controller = CredentialsController(
      repository: repository,
      documentPipeline: pipeline,
      complianceRepository: compliance,
      session: session,
    )..beginMissingCreate(['first_aid', 'ndis_worker_screening']);
    Get.put(controller);

    await tester.pumpWidget(
      const GetMaterialApp(home: CredentialMissingCreateView()),
    );
    await tester.pump();

    expect(find.text('Add missing credentials'), findsOneWidget);
    expect(find.text('First Aid'), findsOneWidget);
    expect(find.text('NDIS Worker Screening Check'), findsOneWidget);
    expect(find.text('Credential type'), findsNothing);
    expect(find.text('Create'), findsNWidgets(2));
    expect(find.text('Upload evidence file'), findsNWidgets(2));
  });
}
