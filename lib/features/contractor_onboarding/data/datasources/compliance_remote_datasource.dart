import 'package:dio/dio.dart';

import '../../../../core/constants/api_paths.dart';
import '../../../../core/errors/app_failure.dart';
import '../models/compliance_models.dart';

class ComplianceRemoteDataSource {
  ComplianceRemoteDataSource({required Dio authenticatedDio})
      : _dio = authenticatedDio;

  final Dio _dio;

  static String newIdempotencyKey(String hint) {
    final t = DateTime.now().toUtc().microsecondsSinceEpoch;
    final safe = hint.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return 'fe-$safe-$t';
  }

  Future<LegalDocumentCurrent> getCurrentLegalDocument(String docKey) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiPaths.legalDocumentsCurrent,
        queryParameters: {'doc_key': docKey},
      );
      final data = response.data;
      if (data == null) {
        throw const AppFailure(
          code: 'legal_document_unavailable',
          message: 'This legal document is not available yet.',
          presentation: AppFailurePresentation.screen,
        );
      }
      return LegalDocumentCurrent.fromJson(data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<List<CollectionNotice>> listCollectionNotices({
    String? credentialType,
    String? jurisdiction,
  }) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiPaths.collectionNotices,
        queryParameters: {
          if (credentialType != null) 'credential_type': credentialType,
          if (jurisdiction != null) 'jurisdiction': jurisdiction,
        },
      );
      final raw = response.data ?? const [];
      return raw
          .whereType<Map>()
          .map((e) => CollectionNotice.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  /// Posts a legal event. Retries should reuse [idempotencyKey].
  Future<LegalEventResult> createLegalEvent(
    LegalEventCreate body, {
    String? idempotencyKey,
  }) async {
    final key = idempotencyKey ??
        body.idempotencyKey ??
        newIdempotencyKey(body.eventType);
    final payload = LegalEventCreate(
      eventType: body.eventType,
      docKey: body.docKey,
      version: body.version,
      noticeKey: body.noticeKey,
      noticeVersion: body.noticeVersion,
      credentialType: body.credentialType,
      dataClass: body.dataClass,
      presentationSource: body.presentationSource,
      idempotencyKey: key,
    );
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.legalEvents,
        data: payload.toJson(),
        options: Options(headers: {'Idempotency-Key': key}),
      );
      final data = response.data;
      if (data == null) {
        throw const AppFailure(
          code: 'unknown',
          message: 'Empty legal-event response',
          presentation: AppFailurePresentation.toast,
        );
      }
      return LegalEventResult.fromJson(data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }
}
