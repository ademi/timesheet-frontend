import 'package:dio/dio.dart';

import '../../app/data/datasources/remote/document_remote_datasource.dart';
import '../../app/data/models/document/document_models.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_failure.dart';

/// Shared document flow: upload-url → PUT signed URL → finalize (+ download-url).
///
/// Prefer this service from repositories/controllers — not raw Dio.
class DocumentService {
  DocumentService({required DocumentRemoteDataSource remote}) : _remote = remote;

  final DocumentRemoteDataSource _remote;

  Future<UploadUrlResponse> createUploadUrl(UploadUrlRequest request) {
    return _remote.createUploadUrl(request);
  }

  Future<void> putToSignedUrl({
    required String uploadUrl,
    required String contentType,
    required List<int> bytes,
  }) {
    return _remote.putToSignedUrl(
      uploadUrl: uploadUrl,
      contentType: contentType,
      bytes: bytes,
    );
  }

  Future<DocumentOut> finalize(String documentId) {
    return _remote.finalize(documentId);
  }

  Future<DocumentOut> uploadBytes({
    required UploadUrlRequest request,
    required List<int> bytes,
  }) {
    return _remote.uploadBytes(request: request, bytes: bytes);
  }

  /// `GET /v1/documents/{id}/download-url`
  Future<String> getDownloadUrl(String documentId) async {
    try {
      final dio = _remote.authenticatedDio;
      final response = await dio.get<Map<String, dynamic>>(
        '${AppConstants.documentsPath}/$documentId/download-url',
      );
      final data = response.data;
      final url = data?['download_url'] as String? ?? data?['url'] as String?;
      if (url == null || url.isEmpty) {
        throw StateError('Empty download URL');
      }
      return url;
    } on DioException catch (e) {
      throw ApiFailure.fromDio(e);
    }
  }
}
