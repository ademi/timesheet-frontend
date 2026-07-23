import 'package:get/get.dart';

import '../../core/network/api_client.dart';
import '../../core/network/attendance_api_client.dart';
import '../../core/services/document_service.dart';
import '../../core/services/token_storage.dart';
import '../data/datasources/remote/document_remote_datasource.dart';
import '../data/repositories/document_repository.dart';

abstract final class DocumentModuleBinding {
  DocumentModuleBinding._();

  static void ensureDependencies() {
    if (!Get.isRegistered<TokenStorage>()) {
      Get.put<TokenStorage>(TokenStorage(), permanent: true);
    }
    if (!Get.isRegistered<ApiClient>()) {
      Get.put<ApiClient>(ApiClient(Get.find<TokenStorage>()), permanent: true);
    }
    if (!Get.isRegistered<AttendanceApiClient>()) {
      Get.put<AttendanceApiClient>(
        AttendanceApiClient(
          Get.find<TokenStorage>(),
          Get.find<ApiClient>().plainDio,
        ),
        permanent: true,
      );
    }
    if (!Get.isRegistered<DocumentRemoteDataSource>()) {
      Get.put<DocumentRemoteDataSource>(
        DocumentRemoteDataSource(
          authenticatedDio: Get.find<AttendanceApiClient>().dio,
        ),
        permanent: true,
      );
    }
    if (!Get.isRegistered<DocumentRepository>()) {
      Get.put<DocumentRepository>(
        DocumentRepository(
          remote: Get.find<DocumentRemoteDataSource>(),
          tokenStorage: Get.find<TokenStorage>(),
        ),
        permanent: true,
      );
    }
    if (!Get.isRegistered<DocumentService>()) {
      Get.put<DocumentService>(
        DocumentService(remote: Get.find<DocumentRemoteDataSource>()),
        permanent: true,
      );
    }
  }
}
