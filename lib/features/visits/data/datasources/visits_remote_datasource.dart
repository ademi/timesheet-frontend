import 'package:dio/dio.dart';

import '../../../../core/constants/api_paths.dart';
import '../../../../core/errors/app_failure.dart';
import '../models/roster_overlay_models.dart';
import '../models/visit_models.dart';

class VisitsRemoteDataSource {
  VisitsRemoteDataSource({required Dio authenticatedDio}) : _dio = authenticatedDio;

  final Dio _dio;

  Future<List<VisitOut>> listVisits({
    DateTime? from,
    DateTime? to,
    String? jobId,
    String? clientId,
    String? status,
    String? paymentStatus,
    int limit = 100,
  }) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiPaths.visits,
        queryParameters: {
          if (from != null) 'from': from.toUtc().toIso8601String(),
          if (to != null) 'to': to.toUtc().toIso8601String(),
          if (jobId != null && jobId.isNotEmpty) 'job_id': jobId,
          if (clientId != null && clientId.isNotEmpty) 'client_id': clientId,
          if (status != null && status.isNotEmpty) 'status': status,
          if (paymentStatus != null && paymentStatus.isNotEmpty)
            'payment_status': paymentStatus,
          'limit': limit,
        },
      );
      return _mapList(response.data, VisitOut.fromJson);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<VisitOut> getVisit(String id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiPaths.visit(id),
      );
      return _require(response.data, VisitOut.fromJson, 'get visit');
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<VisitOut> reschedule({
    required String id,
    required DateTime scheduledStart,
    required DateTime scheduledEnd,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        ApiPaths.visit(id),
        data: {
          'scheduled_start': scheduledStart.toUtc().toIso8601String(),
          'scheduled_end': scheduledEnd.toUtc().toIso8601String(),
        },
      );
      return _require(response.data, VisitOut.fromJson, 'reschedule visit');
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<void> cancel(String id) async {
    try {
      await _dio.post<void>(ApiPaths.visitCancel(id));
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<VisitCheckInOut> checkIn({
    required String id,
    required VisitGpsBody body,
    required String idempotencyKey,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.visitCheckIn(id),
        data: body.toJson(),
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      );
      return _require(response.data, VisitCheckInOut.fromJson, 'check-in');
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<VisitCompleteOut> complete({
    required String id,
    required VisitGpsBody body,
    required String idempotencyKey,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.visitComplete(id),
        data: body.toJson(),
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      );
      return _require(response.data, VisitCompleteOut.fromJson, 'complete');
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<VisitTaskOut> patchTask({
    required String visitId,
    required String taskId,
    required bool isDone,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        ApiPaths.visitTask(visitId, taskId),
        data: {'is_done': isDone},
      );
      return _require(response.data, VisitTaskOut.fromJson, 'patch task');
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<void> submitForm({
    required String visitId,
    required VisitFormSubmitRequest body,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        ApiPaths.visitFormSubmissions(visitId),
        data: body.toJson(),
      );
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  /// Active form templates attached to the job (staff `jobs.read`).
  Future<List<JobFormCatalogItem>> listJobFormCatalog(String jobId) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiPaths.jobFormCatalog(jobId),
      );
      return _mapList(response.data, JobFormCatalogItem.fromJson);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  /// Leave + availability for engaged contractors in a window (`shifts.read`).
  Future<RosterOverlayOut> fetchRosterOverlay({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiPaths.workforceRosterOverlay,
        queryParameters: {
          'from': from.toUtc().toIso8601String(),
          'to': to.toUtc().toIso8601String(),
        },
      );
      return _require(response.data, RosterOverlayOut.fromJson, 'roster overlay');
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
