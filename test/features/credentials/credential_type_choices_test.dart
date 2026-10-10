import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/constants/app_permissions.dart';
import 'package:rostiq/features/contractor_onboarding/data/repositories/compliance_repository.dart';
import 'package:rostiq/features/credentials/controllers/credentials_controller.dart';
import 'package:rostiq/features/credentials/data/models/credential_models.dart';
import 'package:rostiq/features/credentials/data/repositories/credentials_repository.dart';
import 'package:rostiq/features/documents/data/document_pipeline.dart';
import 'package:rostiq/core/services/session_service.dart';

class _MockCredentialsRepository extends Mock
    implements CredentialsRepository {}

class _MockDocumentPipeline extends Mock implements DocumentPipeline {}

class _MockComplianceRepository extends Mock implements ComplianceRepository {}

class _MockSessionService extends Mock implements SessionService {}

void main() {
  late CredentialsController controller;

  setUp(() {
    Get.testMode = true;
    clearCredentialCategoryLabelCache();
    CredentialsController.pendingMissingCreateTypes = null;
    final repository = _MockCredentialsRepository();
    final pipeline = _MockDocumentPipeline();
    final compliance = _MockComplianceRepository();
    final session = _MockSessionService();

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

    controller = CredentialsController(
      repository: repository,
      documentPipeline: pipeline,
      complianceRepository: compliance,
      session: session,
    );
  });

  tearDown(() {
    CredentialsController.pendingMissingCreateTypes = null;
    Get.reset();
  });

  test('credentialTypeChoices keeps Other as the last option', () {
    final choices = controller.credentialTypeChoices;
    expect(choices, isNotEmpty);
    expect(choices.last, 'other');
    expect(choices.where((c) => c == 'other'), hasLength(1));
    final otherIndex = choices.indexOf('other');
    final otherHealthIndex = choices.indexOf('other_health_qualification');
    expect(otherHealthIndex, greaterThanOrEqualTo(0));
    expect(otherHealthIndex, lessThan(otherIndex));
  });

  test('beginMissingCreate builds one draft per missing category', () {
    controller.beginMissingCreate([
      'first_aid',
      'ndis_worker_screening',
      'first_aid',
      ' unknown_type ',
    ]);

    expect(controller.missingCreateTypes, [
      'first_aid',
      'ndis_worker_screening',
      'unknown_type',
    ]);
    expect(controller.missingDrafts.keys, [
      'first_aid',
      'ndis_worker_screening',
      'unknown_type',
    ]);
    expect(
      controller.missingDrafts['first_aid']!.credentialType,
      'first_aid',
    );
    expect(
      CredentialsController.pendingMissingCreateTypes,
      ['first_aid', 'ndis_worker_screening', 'unknown_type'],
    );
  });

  test('ensureMissingCreateFromRoute restores from pending after clear', () {
    controller.beginMissingCreate(['first_aid', 'passport_id']);
    controller.missingCreateTypes.clear();
    controller.missingDrafts.clear();

    controller.ensureMissingCreateFromRoute();

    expect(controller.missingCreateTypes, ['first_aid', 'passport_id']);
    expect(controller.missingDrafts.keys, ['first_aid', 'passport_id']);
  });
}
