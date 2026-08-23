import 'package:dio/dio.dart';

import '../../../../core/constants/api_paths.dart';
import '../../../../core/errors/app_failure.dart';
import '../models/billing_models.dart';

class BillingRemoteDataSource {
  BillingRemoteDataSource({required Dio authenticatedDio}) : _dio = authenticatedDio;

  final Dio _dio;

  Future<List<InvoiceExportOut>> listInvoiceExports({int limit = 100}) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiPaths.invoiceExports,
        queryParameters: {'limit': limit},
      );
      return _mapList(response.data, InvoiceExportOut.fromJson);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<InvoiceExportOut> createInvoiceExport(
    InvoiceExportCreateRequest body,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.invoiceExports,
        data: body.toJson(),
      );
      return _require(response.data, InvoiceExportOut.fromJson, 'create export');
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<InvoiceExportOut> getInvoiceExport(String exportId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiPaths.invoiceExport(exportId),
      );
      return _require(response.data, InvoiceExportOut.fromJson, 'get export');
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<String> downloadInvoiceExportCsv(String exportId) async {
    try {
      final response = await _dio.get<String>(
        ApiPaths.invoiceExportCsv(exportId),
        options: Options(responseType: ResponseType.plain),
      );
      final csv = response.data;
      if (csv == null || csv.isEmpty) {
        throw AppFailure(
          code: 'unknown',
          message: 'Empty CSV export response',
          presentation: AppFailurePresentation.toast,
        );
      }
      return csv;
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<InvoiceExportOut> voidInvoiceExport(String exportId) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.invoiceExportVoid(exportId),
      );
      return _require(response.data, InvoiceExportOut.fromJson, 'void export');
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
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

  T _require<T>(
    Map<String, dynamic>? data,
    T Function(Map<String, dynamic>) fromJson,
    String label,
  ) {
    if (data == null) {
      throw AppFailure(
        code: 'unknown',
        message: 'Empty $label response',
        presentation: AppFailurePresentation.toast,
      );
    }
    return fromJson(data);
  }
}
