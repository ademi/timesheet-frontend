import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../models/document/document_models.dart';
import '../../../../core/constants/api_paths.dart';
import '../../../../core/errors/app_failure.dart';

/// Document upload flow: upload-url → PUT signed URL → finalize.
class DocumentRemoteDataSource {
  DocumentRemoteDataSource({
    required Dio authenticatedDio,
    Dio? plainDio,
  })  : _authenticatedDio = authenticatedDio,
        _plainDio = plainDio ?? Dio();

  final Dio _authenticatedDio;
  final Dio _plainDio;

  /// Exposed for [DocumentService] download-url calls.
  Dio get authenticatedDio => _authenticatedDio;

  Future<UploadUrlResponse> createUploadUrl(UploadUrlRequest request) async {
    try {
      final response = await _authenticatedDio.post<Map<String, dynamic>>(
        ApiPaths.documentsUploadUrl,
        data: request.toJson(),
      );
      final data = response.data;
      if (data == null) {
        throw const AppFailure(
          code: 'unknown',
          message: 'Empty upload-url response',
          presentation: AppFailurePresentation.toast,
        );
      }
      return UploadUrlResponse.fromJson(data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  /// PUT binary bytes to the signed GCS URL with matching Content-Type.
  Future<void> putToSignedUrl({
    required String uploadUrl,
    required String contentType,
    required List<int> bytes,
  }) async {
    try {
      final response = await _plainDio.put<void>(
        uploadUrl,
        data: Uint8List.fromList(bytes),
        options: Options(
          headers: {'Content-Type': contentType},
          followRedirects: true,
          validateStatus: (status) => status != null && status < 400,
        ),
      );
      if (response.statusCode == null || response.statusCode! >= 400) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          message: 'Signed URL PUT failed (${response.statusCode})',
        );
      }
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<DocumentOut> finalize(
    String documentId, {
    String? credentialId,
  }) async {
    try {
      final response = await _authenticatedDio.post<Map<String, dynamic>>(
        ApiPaths.documentFinalize(documentId),
        data: {
          if (credentialId != null) 'credential_id': credentialId,
        },
      );
      final data = response.data;
      if (data == null) {
        throw const AppFailure(
          code: 'unknown',
          message: 'Empty finalize response',
          presentation: AppFailurePresentation.toast,
        );
      }
      return DocumentOut.fromJson(data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  /// Full spike path: upload-url → PUT → finalize.
  Future<DocumentOut> uploadBytes({
    required UploadUrlRequest request,
    required List<int> bytes,
    String? credentialId,
  }) async {
    final upload = await createUploadUrl(request);
    await putToSignedUrl(
      uploadUrl: upload.uploadUrl,
      contentType: request.contentType,
      bytes: bytes,
    );
    return finalize(upload.documentId, credentialId: credentialId);
  }
}
