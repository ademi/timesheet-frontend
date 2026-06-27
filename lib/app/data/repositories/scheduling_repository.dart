import '../../../core/services/token_storage.dart';
import '../datasources/remote/scheduling_remote_datasource.dart';
import '../models/scheduling/assignment_models.dart';
import '../models/scheduling/copy_week_models.dart';
import '../models/scheduling/employee_schedule_models.dart';
import '../models/scheduling/leave_models.dart';
import '../models/scheduling/schedule_board.dart';
import '../models/scheduling/schedule_template.dart';
import '../models/scheduling/shift_status.dart';
import '../models/scheduling/template_request_models.dart';

class SchedulingRepository {
  SchedulingRepository({
    required SchedulingRemoteDataSource remote,
    required TokenStorage tokenStorage,
  })  : _remote = remote,
        _tokenStorage = tokenStorage;

  final SchedulingRemoteDataSource _remote;
  final TokenStorage _tokenStorage;

  String? _resolveBranchId(String? branchId) {
    final resolved = branchId ?? _tokenStorage.branchId;
    if (resolved == null || resolved.isEmpty) {
      throw StateError('No branch selected.');
    }
    return resolved;
  }

  Future<ScheduleBoard> getBoardToday({
    String? branchId,
    ShiftStatus? status,
  }) =>
      _remote.getBoardToday(
        branchId: _resolveBranchId(branchId)!,
        status: status,
      );

  Future<ScheduleBoard> getBoard({
    String? branchId,
    required DateTime start,
    required DateTime end,
    ShiftStatus? status,
  }) =>
      _remote.getBoard(
        branchId: _resolveBranchId(branchId)!,
        start: start,
        end: end,
        status: status,
      );

  Future<List<ScheduleTemplate>> getTemplates({String? branchId}) =>
      _remote.getTemplates(branchId: branchId ?? _tokenStorage.branchId);

  Future<IdResponse> upsertAssignment(AssignmentUpsertRequest body) =>
      _remote.upsertAssignment(body);

  Future<List<AssignmentOut>> listAssignments({
    required DateTime start,
    required DateTime end,
    String? branchId,
  }) =>
      _remote.listAssignments(
        start: start,
        end: end,
        branchId: _resolveBranchId(branchId)!,
      );

  Future<void> deleteAssignment(String assignmentId) =>
      _remote.deleteAssignment(assignmentId);

  Future<IdResponse> createLeave(LeaveCreateRequest body) =>
      _remote.createLeave(body);

  Future<void> deleteLeave(String leaveId) => _remote.deleteLeave(leaveId);

  Future<IdResponse> createEmployeeSchedule(
    EmployeeScheduleCreateRequest body,
  ) =>
      _remote.createEmployeeSchedule(body);

  Future<List<EmployeeScheduleOut>> listEmployeeSchedules({
    required String employeeId,
  }) =>
      _remote.listEmployeeSchedules(employeeId: employeeId);

  Future<void> patchEmployeeSchedule(
    String scheduleId,
    EmployeeSchedulePatchRequest body,
  ) =>
      _remote.patchEmployeeSchedule(scheduleId, body);

  Future<void> deleteEmployeeSchedule(String scheduleId) =>
      _remote.deleteEmployeeSchedule(scheduleId);

  Future<BulkAssignmentResult> bulkAssign(BulkAssignmentRequest body) =>
      _remote.bulkAssign(body);

  Future<CopyWeekResult> copyWeek(CopyWeekRequest body) =>
      _remote.copyWeek(body);

  Future<ScheduleTemplate> createTemplate(TemplateCreateRequest body) =>
      _remote.createTemplate(body);

  Future<ScheduleTemplate> patchTemplate(
    String templateId,
    TemplatePatchRequest body,
  ) =>
      _remote.patchTemplate(templateId, body);
}
