import 'package:dio/dio.dart';

import '../../../../core/constants/api_paths.dart';
import '../../../../core/errors/app_failure.dart';
import '../models/job_models.dart';

class JobsRemoteDataSource {
  JobsRemoteDataSource({required Dio authenticatedDio}) : _dio = authenticatedDio;

  final Dio _dio;

  Future<List<JobOut>> listJobs({int limit = 100}) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiPaths.jobs,
        queryParameters: {'limit': limit},
      );
      return _mapList(response.data, JobOut.fromJson);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<JobOut> getJob(String jobId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiPaths.job(jobId),
      );
      return _require(response.data, JobOut.fromJson, 'get job');
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<JobOut> createJob(JobCreateRequest body) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.jobs,
        data: body.toJson(),
      );
      return _require(response.data, JobOut.fromJson, 'create job');
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<JobOut> updateJobStatus(String jobId, String status) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        ApiPaths.job(jobId),
        data: {'status': status},
      );
      return _require(response.data, JobOut.fromJson, 'update job');
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<List<JobFormCatalogOut>> listFormCatalog(String jobId) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiPaths.jobFormCatalog(jobId),
      );
      return _mapList(response.data, JobFormCatalogOut.fromJson);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<void> addFormCatalog(String jobId, String formTemplateId) async {
    try {
      await _dio.post<void>(
        ApiPaths.jobFormCatalog(jobId),
        data: {'form_template_id': formTemplateId},
      );
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<List<RecurrenceRuleOut>> listRecurrenceRules(String jobId) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiPaths.jobRecurrenceRules(jobId),
      );
      return _mapList(response.data, RecurrenceRuleOut.fromJson);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<RecurrenceRuleOut> createRecurrenceRule(
    String jobId,
    RecurrenceRuleCreateRequest body,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.jobRecurrenceRules(jobId),
        data: body.toJson(),
      );
      return _require(response.data, RecurrenceRuleOut.fromJson, 'create rule');
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<RecurrenceRuleOut> patchRecurrenceRule({
    required String jobId,
    required String ruleId,
    required bool isActive,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        ApiPaths.jobRecurrenceRule(jobId, ruleId),
        data: {'is_active': isActive},
      );
      return _require(response.data, RecurrenceRuleOut.fromJson, 'patch rule');
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<GenerateVisitsResponse> generateVisits({
    required String jobId,
    required String ruleId,
    required GenerateVisitsRequest body,
    required String idempotencyKey,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.jobRecurrenceGenerate(jobId, ruleId),
        data: body.toJson(),
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      );
      return _require(
        response.data,
        GenerateVisitsResponse.fromJson,
        'generate visits',
      );
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<void> createManualVisit(
    String jobId,
    ManualVisitCreateRequest body,
  ) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        ApiPaths.jobVisits(jobId),
        data: body.toJson(),
      );
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<List<FormTemplateOut>> listFormTemplates({
    String? clientId,
    bool tenantLevel = false,
  }) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiPaths.formTemplates,
        queryParameters: {
          if (clientId != null) 'client_id': clientId,
          if (tenantLevel) 'tenant_level': true,
        },
      );
      return _mapList(response.data, FormTemplateOut.fromJson);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<FormTemplateOut> createFormTemplate(
    FormTemplateCreateRequest body,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.formTemplates,
        data: body.toJson(),
      );
      return _require(
        response.data,
        FormTemplateOut.fromJson,
        'create form template',
      );
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<FormTemplateOut> patchFormTemplate(
    String id, {
    String? name,
    bool? isActive,
    Map<String, dynamic>? schemaJson,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        ApiPaths.formTemplate(id),
        data: {
          if (name != null) 'name': name,
          if (isActive != null) 'is_active': isActive,
          if (schemaJson != null) 'schema_json': schemaJson,
        },
      );
      return _require(
        response.data,
        FormTemplateOut.fromJson,
        'patch form template',
      );
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<void> deleteFormTemplate(String id) async {
    try {
      await _dio.delete<void>(ApiPaths.formTemplate(id));
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<List<BranchOut>> listBranches() async {
    try {
      final response = await _dio.get<List<dynamic>>(ApiPaths.branches);
      return _mapList(response.data, BranchOut.fromJson);
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
