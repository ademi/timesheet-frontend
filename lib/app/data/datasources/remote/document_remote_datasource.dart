import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../models/document/document_models.dart';

/// Document upload flow: upload-url → PUT signed URL → finalize.
class DocumentRemoteDataSource {
  DocumentRemoteDataSource({
    required Dio authenticatedDio,
    Dio? plainDio,
  })  : _authenticatedDio = authenticatedDio,
        _plainDio = plainDio ?? Dio();

  final Dio _authenticatedDio;
  final Dio _plainDio;

  Future<UploadUrlResponse> createUploadUrl(UploadUrlRequest request) async {
    final response = await _authenticatedDio.post<Map<String, dynamic>>(
      '/v1/documents/upload-url',
      data: request.toJson(),
    );
    final data = response.data;
    if (data == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        message: 'Empty upload-url response',
      );
    }
    return UploadUrlResponse.fromJson(data);
  }

  /// PUT binary bytes to the signed GCS URL with matching Content-Type.
  Future<void> putToSignedUrl({
    required String uploadUrl,
    required String contentType,
    required List<int> bytes,
  }) async {
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
  }

  Future<DocumentOut> finalize(String documentId) async {
    final response = await _authenticatedDio.post<Map<String, dynamic>>(
      '/v1/documents/$documentId/finalize',
    );
    final data = response.data;
    if (data == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        message: 'Empty finalize response',
      );
    }
    return DocumentOut.fromJson(data);
  }

  /// Full spike path: upload-url → PUT → finalize.
  Future<DocumentOut> uploadBytes({
    required UploadUrlRequest request,
    required List<int> bytes,
  }) async {
    final upload = await createUploadUrl(request);
    await putToSignedUrl(
      uploadUrl: upload.uploadUrl,
      contentType: request.contentType,
      bytes: bytes,
    );
    return finalize(upload.documentId);
  }
}
