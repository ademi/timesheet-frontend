import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/constants/app_permissions.dart';
import 'package:rostiq/features/contractor_onboarding/data/repositories/compliance_repository.dart';
import 'package:rostiq/features/credentials/controllers/credentials_controller.dart';
import 'package:rostiq/features/credentials/data/models/credential_models.dart';
import 'package:rostiq/features/credentials/data/repositories/credentials_repository.dart';
import 'package:rostiq/features/credentials/views/credential_create_view.dart';
import 'package:rostiq/features/documents/data/document_pipeline.dart';
import 'package:rostiq/core/services/session_service.dart';

class _MockCredentialsRepository extends Mock implements CredentialsRepository {}

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

    when(() => session.hasPermission(AppPermissions.credentialsRead)).thenReturn(true);
    when(() => session.hasPermission(AppPermissions.credentialsManage)).thenReturn(true);
    when(() => session.contractorId).thenReturn(RxnString('contractor-1'));
    when(() => session.claims).thenReturn(null);
    when(() => repository.listMine()).thenAnswer((_) async => []);
  });

  tearDown(Get.reset);

  CredentialsController _controller() => CredentialsController(
    repository: repository,
    documentPipeline: pipeline,
    complianceRepository: compliance,
    session: session,
  );

  testWidgets('shows help link after catalog loads without changing type', (
    tester,
  ) async {
    when(() => repository.listCredentialCategories()).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      const categories = [
        CredentialCategory(
          code: 'wwcc',
          label: 'Working with Children Check',
          helpUrl: 'https://example.com/wwcc',
        ),
      ];
      cacheCredentialCategoryLabels(categories);
      return categories;
    });

    final controller = _controller()..selectedType.value = 'wwcc';
    Get.put(controller);

    await tester.pumpWidget(
      const GetMaterialApp(home: CredentialCreateView()),
    );
    await tester.pump();

    expect(find.text('Get this credential'), findsNothing);

    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('Get this credential'), findsOneWidget);
  });

  testWidgets('hides help link when catalog has no help_url for type', (
    tester,
  ) async {
    when(() => repository.listCredentialCategories()).thenAnswer((_) async {
      const categories = [
        CredentialCategory(code: 'passport_id', label: 'Passport'),
      ];
      cacheCredentialCategoryLabels(categories);
      return categories;
    });

    final controller = _controller()..selectedType.value = 'passport_id';
    Get.put(controller);

    await tester.pumpWidget(
      const GetMaterialApp(home: CredentialCreateView()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Get this credential'), findsNothing);
  });
}
