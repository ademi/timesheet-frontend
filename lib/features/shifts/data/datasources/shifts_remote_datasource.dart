import 'package:dio/dio.dart';

import '../../../../core/constants/api_paths.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../jobs/data/models/job_models.dart';
import '../../../rostering/data/composer_models.dart';
import '../models/shift_models.dart';
import '../models/shift_travel_models.dart';

class ShiftsRemoteDataSource {
  ShiftsRemoteDataSource({required Dio authenticatedDio})
    : _dio = authenticatedDio;

  final Dio _dio;

  Future<List<ShiftOut>> listShifts({
    DateTime? from,
    DateTime? to,
    String? jobId,
    String? participantId,
    String? include,
    int limit = 200,
  }) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiPaths.shifts,
        queryParameters: {
          if (from != null) 'from': from.toUtc().toIso8601String(),
          if (to != null) 'to': to.toUtc().toIso8601String(),
          if (jobId != null && jobId.isNotEmpty) 'job_id': jobId,
          if (participantId != null && participantId.isNotEmpty)
            'participant_id': participantId,
          'include':
              (include != null && include.isNotEmpty)
                  ? include
                  : 'participants_summary',
          'limit': limit,
        },
      );
      return _mapList(response.data, ShiftOut.fromJson);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<List<OpenShiftOut>> listOpenShifts({
    DateTime? from,
    DateTime? to,
    int limit = 100,
  }) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiPaths.shiftsOpen,
        queryParameters: {
          if (from != null) 'from': from.toUtc().toIso8601String(),
          if (to != null) 'to': to.toUtc().toIso8601String(),
          'limit': limit,
        },
      );
      return _mapList(response.data, OpenShiftOut.fromJson);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<ShiftOut> getShift(String id, {bool includeTravel = false}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiPaths.shift(id),
        queryParameters: includeTravel ? const {'include': 'travel'} : null,
      );
      return ShiftOut.fromJson(response.data!);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<List<ShiftTravelOut>> listTravel(String shiftId) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiPaths.shiftTravel(shiftId),
      );
      return _mapList(response.data, ShiftTravelOut.fromJson);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<ShiftTravelOut> createTravel(
    String shiftId,
    ShiftTravelWrite body,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.shiftTravel(shiftId),
        data: body.toJson(),
      );
      return ShiftTravelOut.fromJson(_require(response.data));
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<ShiftTravelOut> updateTravel(
    String shiftId,
    String travelId,
    ShiftTravelWrite body,
  ) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        ApiPaths.shiftTravelItem(shiftId, travelId),
        data: body.toJson(),
      );
      return ShiftTravelOut.fromJson(_require(response.data));
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<void> deleteTravel(String shiftId, String travelId) async {
    try {
      await _dio.delete<void>(ApiPaths.shiftTravelItem(shiftId, travelId));
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<ShiftOut> createShift(ShiftCreateRequest body) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.shifts,
        data: body.toJson(),
      );
      return ShiftOut.fromJson(response.data!);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<ShiftOut> publishShift(String id, {ShiftPublishRequest? body}) async {
    try {
      final payload = body?.toJson();
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.shiftPublish(id),
        data: payload != null && payload.isNotEmpty ? payload : null,
      );
      return ShiftOut.fromJson(response.data!);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<ShiftOut> patchShift(String shiftId, ShiftPatchRequest body) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        ApiPaths.shift(shiftId),
        data: body.toJson(),
      );
      return ShiftOut.fromJson(response.data!);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<ComposerShiftOut> getComposer(String shiftId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiPaths.shiftComposer(shiftId),
      );
      return ComposerShiftOut.fromJson(_require(response.data));
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<ComposerShiftOut> copyShift(
    String shiftId,
    ShiftCopyRequest body,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.shiftCopy(shiftId),
        data: body.toJson(),
      );
      return ComposerShiftOut.fromJson(_require(response.data));
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<PlaceOptionsOut> fetchPlaceOptions({
    List<String> participantIds = const [],
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.shiftsPlaceOptions,
        data: {'participant_ids': participantIds},
      );
      return PlaceOptionsOut.fromJson(_require(response.data));
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<List<ShiftFormOverrideOut>> listFormOverrides(String shiftId) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiPaths.shiftFormOverrides(shiftId),
      );
      return _mapList(response.data, ShiftFormOverrideOut.fromJson);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<List<ShiftFormOverrideOut>> putFormOverrides(
    String shiftId,
    List<ShiftFormOverrideOut> overrides,
  ) async {
    try {
      final response = await _dio.put<List<dynamic>>(
        ApiPaths.shiftFormOverrides(shiftId),
        data: {
          'overrides': [for (final o in overrides) o.toJson()],
        },
      );
      return _mapList(response.data, ShiftFormOverrideOut.fromJson);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<List<SupportSegmentOut>> listVisitSegments(
    String shiftId,
    String visitId,
  ) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiPaths.shiftVisitSegments(shiftId, visitId),
      );
      return _mapList(response.data, SupportSegmentOut.fromJson);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<List<SupportSegmentOut>> putVisitSegments(
    String shiftId,
    String visitId,
    List<SupportSegmentIn> segments,
  ) async {
    try {
      final response = await _dio.put<List<dynamic>>(
        ApiPaths.shiftVisitSegments(shiftId, visitId),
        data: {
          'segments': [for (final s in segments) s.toJson()],
        },
      );
      return _mapList(response.data, SupportSegmentOut.fromJson);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<List<ResolvedFormPreviewOut>> previewForms(
    FormPreviewRequirementsRequest body,
  ) async {
    try {
      final response = await _dio.post<List<dynamic>>(
        ApiPaths.formsPreviewRequirements,
        data: body.toJson(),
      );
      return _mapList(response.data, ResolvedFormPreviewOut.fromJson);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<AssignContextOut> fetchAssignContext({
    required DateTime from,
    required DateTime to,
    String? clientId,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiPaths.rosterAssignContext,
        queryParameters: {
          'from': from.toUtc().toIso8601String(),
          'to': to.toUtc().toIso8601String(),
          if (clientId != null && clientId.isNotEmpty) 'client_id': clientId,
        },
      );
      return AssignContextOut.fromJson(_require(response.data));
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<ShiftOut> putParticipants(
    String shiftId,
    ShiftParticipantsReplaceRequest body,
  ) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        ApiPaths.shiftParticipants(shiftId),
        data: body.toJson(),
      );
      return ShiftOut.fromJson(response.data!);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  /// Soft-remove by client [participantId] (not shift_participant row id).
  Future<ShiftOut> removeParticipant(
    String shiftId,
    String participantId, {
    required String reason,
    String rebalance = 'equal',
  }) async {
    try {
      final response = await _dio.delete<Map<String, dynamic>>(
        ApiPaths.shiftParticipant(shiftId, participantId),
        queryParameters: {'reason': reason, 'rebalance': rebalance},
      );
      return ShiftOut.fromJson(response.data!);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<List<AllocationChangeLogOut>> getAllocationChanges(
    String shiftId,
  ) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiPaths.shiftAllocationChanges(shiftId),
      );
      return _mapList(response.data, AllocationChangeLogOut.fromJson);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<ShiftOut> assignShift({
    required String shiftId,
    required String contractorId,
    List<TaskTemplateItem>? taskTemplate,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.shiftAssign(shiftId),
        data: {
          'contractor_id': contractorId,
          if (taskTemplate != null && taskTemplate.isNotEmpty)
            'task_template': [for (final task in taskTemplate) task.toJson()],
        },
      );
      return ShiftOut.fromJson(response.data!);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<ShiftOut> assignShiftBatch({
    required String shiftId,
    required List<String> contractorIds,
    List<TaskTemplateItem>? taskTemplate,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.shiftAssignBatch(shiftId),
        data: {
          'contractor_ids': contractorIds,
          if (taskTemplate != null && taskTemplate.isNotEmpty)
            'task_template': [for (final task in taskTemplate) task.toJson()],
        },
      );
      return ShiftOut.fromJson(response.data!);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<ShiftOut> unassignShift(String shiftId, String contractorId) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.shiftUnassign(shiftId),
        data: {'contractor_id': contractorId},
      );
      return ShiftOut.fromJson(_require(response.data));
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<ShiftOut> claimShift(String id) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.shiftClaim(id),
      );
      return ShiftOut.fromJson(response.data!);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<ShiftOut> cancelShift(String id) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.shiftCancel(id),
      );
      return ShiftOut.fromJson(response.data!);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  List<T> _mapList<T>(
    List<dynamic>? data,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (data == null) return const [];
    return data
        .whereType<Map>()
        .map((e) => fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  Map<String, dynamic> _require(Map<String, dynamic>? data) {
    if (data == null) {
      throw const AppFailure(
        code: 'unknown',
        message: 'Empty shift response',
        presentation: AppFailurePresentation.toast,
      );
    }
    return data;
  }
}
