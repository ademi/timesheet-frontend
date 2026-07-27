import 'package:get/get.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/token_storage.dart';
import '../../contractor_onboarding/data/datasources/compliance_remote_datasource.dart';
import '../../contractor_onboarding/data/repositories/compliance_repository.dart';
import '../../documents/data/datasources/documents_remote_datasource.dart';
import '../../documents/data/document_pipeline.dart';
import '../controllers/credentials_controller.dart';
import '../controllers/staff_credential_review_controller.dart';
import '../data/datasources/credentials_remote_datasource.dart';
import '../data/repositories/credentials_repository.dart';

class CredentialsBinding extends Bindings {
  @override
  void dependencies() => ensure();

  /// [permanent] keeps the controller across onboarding step route replaces.
  static void ensure({bool permanent = false}) {
    _ensureShared();
    if (!Get.isRegistered<CredentialsController>()) {
      if (!Get.isRegistered<SessionService>()) {
        // Session is registered by AuthBinding after login; skip if missing.
        return;
      }
      Get.put<CredentialsController>(
        CredentialsController(
          repository: Get.find<CredentialsRepository>(),
          documentPipeline: Get.find<DocumentPipeline>(),
          complianceRepository: Get.find<ComplianceRepository>(),
          session: Get.find<SessionService>(),
        ),
        permanent: permanent,
      );
    }
  }

  static void ensureDependencies() => _ensureShared();

  static void _ensureShared() {
    if (!Get.isRegistered<TokenStorage>()) {
      Get.put<TokenStorage>(TokenStorage(), permanent: true);
    }
    if (!Get.isRegistered<ApiClient>()) {
      Get.put<ApiClient>(
        ApiClient(Get.find<TokenStorage>()),
        permanent: true,
      );
    }
    if (!Get.isRegistered<CredentialsRemoteDataSource>()) {
      Get.lazyPut<CredentialsRemoteDataSource>(
        () => CredentialsRemoteDataSource(
          authenticatedDio: Get.find<ApiClient>().dio,
        ),
        fenix: true,
      );
    }
    if (!Get.isRegistered<CredentialsRepository>()) {
      Get.lazyPut<CredentialsRepository>(
        () => CredentialsRepository(
          remote: Get.find<CredentialsRemoteDataSource>(),
        ),
        fenix: true,
      );
    }
    if (!Get.isRegistered<DocumentsRemoteDataSource>()) {
      Get.lazyPut<DocumentsRemoteDataSource>(
        () => DocumentsRemoteDataSource(
          authenticatedDio: Get.find<ApiClient>().dio,
          plainDio: Get.find<ApiClient>().plainDio,
        ),
        fenix: true,
      );
    }
    if (!Get.isRegistered<DocumentPipeline>()) {
      Get.lazyPut<DocumentPipeline>(
        () => DocumentPipeline(remote: Get.find<DocumentsRemoteDataSource>()),
        fenix: true,
      );
    }
    if (!Get.isRegistered<ComplianceRemoteDataSource>()) {
      Get.lazyPut<ComplianceRemoteDataSource>(
        () => ComplianceRemoteDataSource(
          authenticatedDio: Get.find<ApiClient>().dio,
        ),
        fenix: true,
      );
    }
    if (!Get.isRegistered<ComplianceRepository>()) {
      Get.lazyPut<ComplianceRepository>(
        () => ComplianceRepository(
          remote: Get.find<ComplianceRemoteDataSource>(),
        ),
        fenix: true,
      );
    }
  }
}

class StaffCredentialReviewBinding extends Bindings {
  @override
  void dependencies() {
    CredentialsBinding.ensureDependencies();
    Get.lazyPut<StaffCredentialReviewController>(
      () => StaffCredentialReviewController(
        repository: Get.find<CredentialsRepository>(),
        session: Get.find<SessionService>(),
      ),
    );
  }
}
