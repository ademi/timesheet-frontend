import 'package:dio/dio.dart';

import '../../app/data/datasources/remote/document_remote_datasource.dart';
import '../../app/data/models/document/document_models.dart';
import '../constants/api_paths.dart';
import '../errors/app_failure.dart';
import '../network/api_failure.dart';

/// Shared document flow: upload-url → PUT signed URL → finalize (+ download).
///
/// Prefer this service from repositories/controllers — not raw Dio.
/// For credential evidence + proxy download, see
/// `features/documents/data/document_pipeline.dart`.
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

  Future<DocumentOut> finalize(
    String documentId, {
    String? credentialId,
  }) {
    return _remote.finalize(documentId, credentialId: credentialId);
  }

  Future<DocumentOut> uploadBytes({
    required UploadUrlRequest request,
    required List<int> bytes,
    String? credentialId,
  }) {
    return _remote.uploadBytes(
      request: request,
      bytes: bytes,
      credentialId: credentialId,
    );
  }

  /// `GET /v1/documents/{id}/download-url`
  Future<String> getDownloadUrl(String documentId) async {
    try {
      final dio = _remote.authenticatedDio;
      final response = await dio.get<Map<String, dynamic>>(
        ApiPaths.documentDownloadUrl(documentId),
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

  /// `GET /v1/documents/{id}/content` — use when download-url returns
  /// `proxy_required`.
  Future<List<int>> getContentBytes(
    String documentId, {
    String? deliveryId,
  }) async {
    try {
      final dio = _remote.authenticatedDio;
      final response = await dio.get<List<int>>(
        ApiPaths.documentContent(documentId),
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            if (deliveryId != null && deliveryId.isNotEmpty)
              'X-Delivery-Id': deliveryId,
          },
        ),
      );
      final data = response.data;
      if (data == null) {
        throw StateError('Empty document content');
      }
      return data;
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }
}
