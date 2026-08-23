import 'package:dio/dio.dart';

import '../../../core/errors/app_failure.dart';
import '../data/models/billing_models.dart';

/// Parses per-visit failures from invoice export create responses.
List<InvoiceExportVisitError> parseInvoiceExportVisitErrors(DioException e) {
  final data = e.response?.data;
  if (data is! Map) return const [];

  final map = Map<String, dynamic>.from(data);
  final detail = map['detail'];
  final errors = <InvoiceExportVisitError>[];

  void addError({
    required String visitId,
    required String code,
    String? message,
  }) {
    if (visitId.isEmpty) return;
    final resolvedMessage = message ?? invoiceExportErrorMessage(code);
    errors.add(
      InvoiceExportVisitError(
        visitId: visitId,
        code: code,
        message: resolvedMessage,
      ),
    );
  }

  if (detail is Map) {
    final detailMap = Map<String, dynamic>.from(detail);
    final rawErrors = detailMap['visit_errors'] ?? detailMap['errors'];
    if (rawErrors is List) {
      for (final item in rawErrors) {
        if (item is! Map) continue;
        final row = Map<String, dynamic>.from(item);
        final visitId =
            row['visit_id']?.toString() ?? row['visitId']?.toString() ?? '';
        final code = row['code']?.toString() ??
            row['detail']?.toString() ??
            detailMap['code']?.toString() ??
            'unknown';
        addError(
          visitId: visitId,
          code: code,
          message: row['message']?.toString() ?? invoiceExportErrorMessage(code),
        );
      }
      return errors;
    }
    final visitId = detailMap['visit_id']?.toString() ?? '';
    final code = detailMap['code']?.toString() ?? 'unknown';
    if (visitId.isNotEmpty) {
      addError(
        visitId: visitId,
        code: code,
        message: detailMap['message']?.toString(),
      );
    }
    return errors;
  }

  if (detail is String) {
    final visitId = map['visit_id']?.toString() ?? '';
    if (visitId.isNotEmpty) {
      addError(visitId: visitId, code: detail);
    }
  }

  return errors;
}

String invoiceExportErrorMessage(String code) {
  return AppFailure.fromDio(
    DioException(
      requestOptions: RequestOptions(path: '/billing/invoice-exports'),
      response: Response(
        requestOptions: RequestOptions(path: '/billing/invoice-exports'),
        data: {'detail': code},
      ),
      type: DioExceptionType.badResponse,
    ),
  ).message;
}
