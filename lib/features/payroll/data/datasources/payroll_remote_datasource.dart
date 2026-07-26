import 'package:dio/dio.dart';

import '../../../../core/constants/api_paths.dart';
import '../../../../core/errors/app_failure.dart';
import '../models/payroll_models.dart';

class PayrollRemoteDataSource {
  PayrollRemoteDataSource({required Dio authenticatedDio}) : _dio = authenticatedDio;

  final Dio _dio;

  Future<List<EngagementRateOut>> listRates(String engagementId) async {
    try {
      final response = await _dio.get<dynamic>(
        ApiPaths.engagementRates(engagementId),
      );
      return _parseRates(response.data, engagementId);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<EngagementRateOut> createRate(
    String engagementId,
    EngagementRateCreateRequest body,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.engagementRates(engagementId),
        data: body.toJson(),
      );
      final data = response.data;
      if (data == null) {
        throw const AppFailure(
          code: 'unknown',
          message: 'Empty rate create response',
          presentation: AppFailurePresentation.toast,
        );
      }
      final out = EngagementRateOut.fromJson(data);
      if (out.engagementId.isEmpty) {
        return EngagementRateOut.fromJson({
          ...data,
          'engagement_id': engagementId,
        });
      }
      return out;
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<EngagementRateOut> patchRate(
    String rateId, {
    String? effectiveTo,
    RateBands? bands,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        ApiPaths.engagementRate(rateId),
        data: {
          if (effectiveTo != null) 'effective_to': effectiveTo,
          if (bands != null) ...{
            'hourly_rate': bands.base,
            'bands': bands.toJson(),
          },
        },
      );
      final data = response.data;
      if (data == null) {
        throw const AppFailure(
          code: 'unknown',
          message: 'Empty rate patch response',
          presentation: AppFailurePresentation.toast,
        );
      }
      return EngagementRateOut.fromJson(data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<List<PaymentBatchOut>> listBatches({
    String? status,
    int limit = 100,
  }) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiPaths.paymentBatches,
        queryParameters: {
          if (status != null && status.isNotEmpty) 'status': status,
          'limit': limit,
        },
      );
      return _mapList(response.data, PaymentBatchOut.fromJson);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<PaymentBatchOut> createBatch(
    PaymentBatchCreateRequest body, {
    required String idempotencyKey,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.paymentBatches,
        data: body.toJson(),
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      );
      final data = response.data;
      if (data == null) {
        throw const AppFailure(
          code: 'unknown',
          message: 'Empty batch create response',
          presentation: AppFailurePresentation.toast,
        );
      }
      return PaymentBatchOut.fromJson(data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<PaymentBatchOut> postBatch(String id) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.paymentBatchPost(id),
      );
      final data = response.data;
      if (data == null) {
        throw const AppFailure(
          code: 'unknown',
          message: 'Empty batch post response',
          presentation: AppFailurePresentation.toast,
        );
      }
      return PaymentBatchOut.fromJson(data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<PaymentBatchOut> voidBatch(String id) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.paymentBatchVoid(id),
      );
      final data = response.data;
      if (data == null) {
        throw const AppFailure(
          code: 'unknown',
          message: 'Empty batch void response',
          presentation: AppFailurePresentation.toast,
        );
      }
      return PaymentBatchOut.fromJson(data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<TenantSettingsOut> getTenant(String tenantId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiPaths.tenant(tenantId),
      );
      final data = response.data;
      if (data == null) {
        throw const AppFailure(
          code: 'unknown',
          message: 'Empty tenant response',
          presentation: AppFailurePresentation.toast,
        );
      }
      return TenantSettingsOut.fromJson(data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<TenantSettingsOut> patchTenant(
    String tenantId, {
    String? timezone,
    String? publicHolidayJurisdiction,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        ApiPaths.tenant(tenantId),
        data: {
          if (timezone != null) 'timezone': timezone,
          if (publicHolidayJurisdiction != null)
            'public_holiday_jurisdiction': publicHolidayJurisdiction,
        },
      );
      final data = response.data;
      if (data == null) {
        throw const AppFailure(
          code: 'unknown',
          message: 'Empty tenant patch response',
          presentation: AppFailurePresentation.toast,
        );
      }
      return TenantSettingsOut.fromJson(data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  List<EngagementRateOut> _parseRates(dynamic data, String engagementId) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) {
            final map = Map<String, dynamic>.from(e);
            map.putIfAbsent('engagement_id', () => engagementId);
            return EngagementRateOut.fromJson(map);
          })
          .toList(growable: false);
    }
    if (data is Map) {
      final items = data['items'] ?? data['rates'] ?? data['data'];
      if (items is List) return _parseRates(items, engagementId);
      final map = Map<String, dynamic>.from(data);
      map.putIfAbsent('engagement_id', () => engagementId);
      return [EngagementRateOut.fromJson(map)];
    }
    return const [];
  }

  List<T> _mapList<T>(
    List<dynamic>? raw,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final list = raw ?? const [];
    return list
        .whereType<Map>()
        .map((e) => fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }
}
