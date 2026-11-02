import 'package:dio/dio.dart';

import '../../../../../core/constants/api_paths.dart';
import '../../../../../core/errors/app_failure.dart';
import '../models/xero_models.dart';

class XeroRemoteDataSource {
  XeroRemoteDataSource({required Dio authenticatedDio}) : _dio = authenticatedDio;

  final Dio _dio;

  Future<XeroConnectionStatus> getStatus() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(ApiPaths.xero);
      final data = response.data;
      if (data == null) {
        throw const AppFailure(
          code: 'unknown',
          message: 'Empty Xero status response',
          presentation: AppFailurePresentation.toast,
        );
      }
      return XeroConnectionStatus.fromJson(data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<XeroAuthUrlOut> getAuthUrl() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(ApiPaths.xeroAuthUrl);
      final data = response.data;
      if (data == null) {
        throw const AppFailure(
          code: 'unknown',
          message: 'Empty Xero auth-url response',
          presentation: AppFailurePresentation.toast,
        );
      }
      return XeroAuthUrlOut.fromJson(data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<XeroDisconnectOut> disconnect() async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.xeroDisconnect,
      );
      final data = response.data;
      if (data == null) {
        throw const AppFailure(
          code: 'unknown',
          message: 'Empty Xero disconnect response',
          presentation: AppFailurePresentation.toast,
        );
      }
      return XeroDisconnectOut.fromJson(data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<List<XeroEmployee>> listEmployees() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiPaths.xeroEmployees,
      );
      final raw = response.data?['employees'];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => XeroEmployee.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<List<XeroEarningsRate>> listEarningsRates() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiPaths.xeroEarningsRates,
      );
      final raw = response.data?['earnings_rates'];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => XeroEarningsRate.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<XeroEmployeeMappingsOut> getEmployeeMappings() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiPaths.xeroEmployeeMappings,
      );
      final data = response.data;
      if (data == null) {
        return const XeroEmployeeMappingsOut();
      }
      return XeroEmployeeMappingsOut.fromJson(data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<XeroEmployeeMappingsOut> putEmployeeMappings(
    XeroEmployeeMappingsOut body,
  ) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        ApiPaths.xeroEmployeeMappings,
        data: body.toJson(),
      );
      final data = response.data;
      if (data == null) {
        throw const AppFailure(
          code: 'unknown',
          message: 'Empty employee mappings response',
          presentation: AppFailurePresentation.toast,
        );
      }
      return XeroEmployeeMappingsOut.fromJson(data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<XeroPayItemMappingsOut> getPayItemMappings() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiPaths.xeroPayItemMappings,
      );
      final data = response.data;
      if (data == null) {
        return const XeroPayItemMappingsOut();
      }
      return XeroPayItemMappingsOut.fromJson(data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<XeroPayItemMappingsOut> putPayItemMappings(
    XeroPayItemMappingsOut body,
  ) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        ApiPaths.xeroPayItemMappings,
        data: body.toJson(),
      );
      final data = response.data;
      if (data == null) {
        throw const AppFailure(
          code: 'unknown',
          message: 'Empty pay-item mappings response',
          presentation: AppFailurePresentation.toast,
        );
      }
      return XeroPayItemMappingsOut.fromJson(data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  /// `POST …/payment-batches/{id}/export-xero` — requires Idempotency-Key.
  Future<XeroExportResult> exportPaymentBatch(
    String batchId, {
    required String idempotencyKey,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.paymentBatchExportXero(batchId),
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      );
      final data = response.data;
      if (data == null) {
        throw const AppFailure(
          code: 'unknown',
          message: 'Empty Xero export response',
          presentation: AppFailurePresentation.toast,
        );
      }
      return XeroExportResult.fromJson(data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }
}
