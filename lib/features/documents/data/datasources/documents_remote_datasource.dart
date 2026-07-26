import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../app/data/models/document/document_models.dart';
import '../../../../core/constants/api_paths.dart';
import '../../../../core/errors/app_failure.dart';

/// Document upload / download / scan helpers (design §5.3 / §6.4).
class DocumentsRemoteDataSource {
  DocumentsRemoteDataSource({
    required Dio authenticatedDio,
    Dio? plainDio,
  })  : _authenticatedDio = authenticatedDio,
        _plainDio = plainDio ?? Dio();

  final Dio _authenticatedDio;
  final Dio _plainDio;

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

  Future<DocumentOut> finalize({
    required String documentId,
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

  Future<List<DocumentOut>> listForOwner({
    required String ownerType,
    required String ownerId,
    int limit = 100,
  }) async {
    try {
      final response = await _authenticatedDio.get<List<dynamic>>(
        ApiPaths.documents,
        queryParameters: {
          'owner_type': ownerType,
          'owner_id': ownerId,
          'limit': limit,
        },
      );
      final raw = response.data ?? const [];
      return raw
          .whereType<Map>()
          .map((e) => DocumentOut.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<DownloadUrlResponse> getDownloadUrl(String documentId) async {
    try {
      final response = await _authenticatedDio.get<Map<String, dynamic>>(
        ApiPaths.documentDownloadUrl(documentId),
      );
      final data = response.data;
      if (data == null) {
        throw const AppFailure(
          code: 'unknown',
          message: 'Empty download-url response',
          presentation: AppFailurePresentation.toast,
        );
      }
      final parsed = DownloadUrlResponse.fromJson(data);
      if (parsed.downloadUrl.isEmpty) {
        throw const AppFailure(
          code: 'unknown',
          message: 'Empty download URL',
          presentation: AppFailurePresentation.toast,
        );
      }
      return parsed;
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  /// Authenticated stream for restricted evidence (`proxy_required`).
  Future<List<int>> getContentBytes(
    String documentId, {
    String? deliveryId,
  }) async {
    try {
      final response = await _authenticatedDio.get<List<int>>(
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
        throw const AppFailure(
          code: 'unknown',
          message: 'Empty document content',
          presentation: AppFailurePresentation.toast,
        );
      }
      return data;
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }
}
