import 'package:dio/dio.dart';

import '../../../../core/constants/api_paths.dart';
import '../../../../core/errors/app_failure.dart';
import '../models/invoice_export_models.dart';

class BillingRemoteDataSource {
  BillingRemoteDataSource({required Dio authenticatedDio})
      : _dio = authenticatedDio;

  final Dio _dio;

  Future<List<InvoiceExportOut>> listExports({int limit = 100}) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiPaths.invoiceExports,
        queryParameters: {'limit': limit},
      );
      return (response.data ?? const [])
          .whereType<Map>()
          .map(
            (export) => InvoiceExportOut.fromJson(
              Map<String, dynamic>.from(export),
            ),
          )
          .toList(growable: false);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<InvoiceExportOut> getExport(String id) =>
      _getExportResponse(ApiPaths.invoiceExport(id), 'get');

  Future<InvoiceExportOut> createExport(
    InvoiceExportCreateRequest body,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.invoiceExports,
        data: body.toJson(),
      );
      return _parseExport(response.data, 'create');
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<InvoiceExportOut> voidExport(String id) =>
      _postExportResponse(ApiPaths.invoiceExportVoid(id), 'void');

  Future<String> downloadCsv(String id) async {
    try {
      final response = await _dio.get<String>(
        ApiPaths.invoiceExportCsv(id),
        options: Options(responseType: ResponseType.plain),
      );
      return response.data ?? '';
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<InvoiceExportOut> _getExportResponse(
    String path,
    String operation,
  ) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(path);
      return _parseExport(response.data, operation);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<InvoiceExportOut> _postExportResponse(
    String path,
    String operation,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(path);
      return _parseExport(response.data, operation);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  InvoiceExportOut _parseExport(
    Map<String, dynamic>? data,
    String operation,
  ) {
    if (data == null) {
      throw AppFailure(
        code: 'unknown',
        message: 'Empty invoice export $operation response',
        presentation: AppFailurePresentation.toast,
      );
    }
    return InvoiceExportOut.fromJson(data);
  }
}
