import 'package:dio/dio.dart';

import '../../../../core/constants/app_constants.dart';
import '../../models/scheduling/assignment_models.dart';
import '../../models/scheduling/copy_week_models.dart';
import '../../models/scheduling/employee_schedule_models.dart';
import '../../models/scheduling/leave_models.dart';
import '../../models/scheduling/schedule_board.dart';
import '../../models/scheduling/schedule_template.dart';
import '../../models/scheduling/scheduling_date_utils.dart';
import '../../models/scheduling/shift_status.dart';
import '../../models/scheduling/template_request_models.dart';

class SchedulingRemoteDataSource {
  SchedulingRemoteDataSource({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<ScheduleBoard> getBoardToday({
    required String branchId,
    ShiftStatus? status,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AppConstants.schedulingBoardTodayPath,
      queryParameters: {
        'branch_id': branchId,
        if (status != null) 'status': status.apiValue,
      },
    );
    return _parseBoard(response);
  }

  Future<ScheduleBoard> getBoard({
    required String branchId,
    required DateTime start,
    required DateTime end,
    ShiftStatus? status,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AppConstants.schedulingBoardPath,
      queryParameters: {
        'branch_id': branchId,
        'start': fmtSchedulingDate(start),
        'end': fmtSchedulingDate(end),
        if (status != null) 'status': status.apiValue,
      },
    );
    return _parseBoard(response);
  }

  Future<List<ScheduleTemplate>> getTemplates({String? branchId}) async {
    final response = await _dio.get<dynamic>(
      AppConstants.schedulingTemplatesPath,
      queryParameters: {
        if (branchId != null && branchId.isNotEmpty) 'branch_id': branchId,
      },
    );
    final data = response.data;
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(ScheduleTemplate.fromJson)
          .toList();
    }
    throw DioException(
      requestOptions: response.requestOptions,
      message: 'Invalid templates response format.',
    );
  }

  Future<IdResponse> upsertAssignment(AssignmentUpsertRequest body) async {
    final response = await _dio.put<Map<String, dynamic>>(
      AppConstants.schedulingAssignmentsPath,
      data: body.toJson(),
    );
    return _parseIdResponse(response);
  }

  Future<List<AssignmentOut>> listAssignments({
    required DateTime start,
    required DateTime end,
    required String branchId,
  }) async {
    final response = await _dio.get<dynamic>(
      AppConstants.schedulingAssignmentsPath,
      queryParameters: {
        'start': fmtSchedulingDate(start),
        'end': fmtSchedulingDate(end),
        'branch_id': branchId,
      },
    );
    final data = response.data;
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(AssignmentOut.fromJson)
          .toList();
    }
    throw DioException(
      requestOptions: response.requestOptions,
      message: 'Invalid assignments response format.',
    );
  }

  Future<void> deleteAssignment(String assignmentId) async {
    await _dio.delete('${AppConstants.schedulingAssignmentsPath}/$assignmentId');
  }

  Future<IdResponse> createLeave(LeaveCreateRequest body) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AppConstants.schedulingLeavePath,
      data: body.toJson(),
    );
    return _parseIdResponse(response);
  }

  Future<void> deleteLeave(String leaveId) async {
    await _dio.delete('${AppConstants.schedulingLeavePath}/$leaveId');
  }

  Future<IdResponse> createEmployeeSchedule(
    EmployeeScheduleCreateRequest body,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AppConstants.schedulingEmployeeSchedulesPath,
      data: body.toJson(),
    );
    return _parseIdResponse(response);
  }

  Future<List<EmployeeScheduleOut>> listEmployeeSchedules({
    required String employeeId,
  }) async {
    final response = await _dio.get<dynamic>(
      AppConstants.schedulingEmployeeSchedulesPath,
      queryParameters: {'employee_id': employeeId},
    );
    final data = response.data;
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(EmployeeScheduleOut.fromJson)
          .toList();
    }
    throw DioException(
      requestOptions: response.requestOptions,
      message: 'Invalid employee schedules response format.',
    );
  }

  Future<void> patchEmployeeSchedule(
    String scheduleId,
    EmployeeSchedulePatchRequest body,
  ) async {
    await _dio.patch(
      '${AppConstants.schedulingEmployeeSchedulesPath}/$scheduleId',
      data: body.toJson(),
    );
  }

  Future<void> deleteEmployeeSchedule(String scheduleId) async {
    await _dio.delete(
      '${AppConstants.schedulingEmployeeSchedulesPath}/$scheduleId',
    );
  }

  Future<BulkAssignmentResult> bulkAssign(BulkAssignmentRequest body) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AppConstants.schedulingAssignmentsBulkPath,
      data: body.toJson(),
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return BulkAssignmentResult.fromJson(data);
    }
    throw DioException(
      requestOptions: response.requestOptions,
      message: 'Invalid bulk assignment response format.',
    );
  }

  Future<CopyWeekResult> copyWeek(CopyWeekRequest body) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AppConstants.schedulingCopyWeekPath,
      data: body.toJson(),
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return CopyWeekResult.fromJson(data);
    }
    throw DioException(
      requestOptions: response.requestOptions,
      message: 'Invalid copy week response format.',
    );
  }

  Future<ScheduleTemplate> createTemplate(TemplateCreateRequest body) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AppConstants.schedulingTemplatesPath,
      data: body.toJson(),
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return ScheduleTemplate.fromJson(data);
    }
    throw DioException(
      requestOptions: response.requestOptions,
      message: 'Invalid create template response format.',
    );
  }

  Future<ScheduleTemplate> patchTemplate(
    String templateId,
    TemplatePatchRequest body,
  ) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '${AppConstants.schedulingTemplatesPath}/$templateId',
      data: body.toJson(),
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return ScheduleTemplate.fromJson(data);
    }
    throw DioException(
      requestOptions: response.requestOptions,
      message: 'Invalid patch template response format.',
    );
  }

  ScheduleBoard _parseBoard(Response<Map<String, dynamic>> response) {
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return ScheduleBoard.fromJson(data);
    }
    throw DioException(
      requestOptions: response.requestOptions,
      message: 'Invalid schedule board response format.',
    );
  }

  IdResponse _parseIdResponse(Response<Map<String, dynamic>> response) {
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return IdResponse.fromJson(data);
    }
    throw DioException(
      requestOptions: response.requestOptions,
      message: 'Invalid id response format.',
    );
  }
}
