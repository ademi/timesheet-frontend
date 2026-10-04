import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:rostiq/app/constants/app_permissions.dart';
import 'package:rostiq/app/data/models/document/document_models.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/compliance_ops/controllers/contractor_profile_controller.dart';
import 'package:rostiq/features/compliance_ops/data/repositories/compliance_ops_repository.dart';
import 'package:rostiq/features/documents/data/document_pipeline.dart';
import 'package:rostiq/shared/models/profile_photo_models.dart';

class _MockComplianceOpsRepository extends Mock
    implements ComplianceOpsRepository {}

class _MockDocumentPipeline extends Mock implements DocumentPipeline {}

class _MockSessionService extends Mock implements SessionService {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const UploadUrlRequest(
        ownerType: 'contractor',
        ownerId: 'c1',
        filename: 'x.jpg',
        contentType: 'image/jpeg',
        sizeBytes: 1,
        category: 'contractor_photo',
      ),
    );
  });

  late _MockComplianceOpsRepository repository;
  late _MockDocumentPipeline pipeline;
  late _MockSessionService session;

  setUp(() {
    Get.testMode = true;
    repository = _MockComplianceOpsRepository();
    pipeline = _MockDocumentPipeline();
    session = _MockSessionService();
    when(
      () => session.hasPermission(AppPermissions.documentsUpload),
    ).thenReturn(true);
    when(() => session.contractorId).thenReturn(RxnString('contractor-1'));
    when(() => session.needsProfileCompletion).thenReturn(false.obs);
  });

  tearDown(Get.reset);

  test('onPhotoPicked holds locally and does not upload', () {
    final controller = ContractorProfileController(
      repository: repository,
      session: session,
      documentPipeline: pipeline,
    );

    controller.onPhotoPicked(
      const PickedProfilePhoto(
        name: 'me.jpg',
        contentType: 'image/jpeg',
        bytes: [1, 2, 3],
      ),
    );

    expect(controller.pendingPhoto.value?.name, 'me.jpg');
    expect(controller.localPhotoBytes.value, [1, 2, 3]);
    expect(controller.hasPendingPhotoChanges, isTrue);
    verifyNever(
      () => pipeline.uploadEvidence(
        request: any(named: 'request'),
        bytes: any(named: 'bytes'),
      ),
    );
    verifyNever(() => repository.setContractorProfilePhoto(any()));
  });

  test('clearPendingPhoto marks server photo for removal without network', () {
    final controller = ContractorProfileController(
      repository: repository,
      session: session,
      documentPipeline: pipeline,
    );
    controller.photo.value = const ProfilePhotoOut(
      documentId: 'doc-1',
      downloadUrl: 'https://example.com/p.jpg',
      hasPhoto: true,
    );

    controller.clearPendingPhoto();

    expect(controller.photoCleared.value, isTrue);
    expect(controller.localPhotoBytes.value, isNull);
    verifyNever(() => repository.clearContractorProfilePhoto());
  });
}
