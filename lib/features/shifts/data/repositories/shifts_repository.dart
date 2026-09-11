import '../../../jobs/data/models/job_models.dart';
import '../datasources/shifts_remote_datasource.dart';
import '../models/shift_models.dart';

class ShiftsRepository {
  ShiftsRepository({required ShiftsRemoteDataSource remote}) : _remote = remote;

  final ShiftsRemoteDataSource _remote;

  Future<List<ShiftOut>> listShifts({
    DateTime? from,
    DateTime? to,
    String? jobId,
    String? participantId,
    String? include,
    int limit = 200,
  }) => _remote.listShifts(
    from: from,
    to: to,
    jobId: jobId,
    participantId: participantId,
    include: include,
    limit: limit,
  );

  Future<List<OpenShiftOut>> listOpenShifts({DateTime? from, DateTime? to}) =>
      _remote.listOpenShifts(from: from, to: to);

  Future<ShiftOut> getShift(String id) => _remote.getShift(id);

  Future<ShiftOut> createShift(ShiftCreateRequest body) =>
      _remote.createShift(body);

  Future<ShiftOut> publishShift(
    String id, {
    ShiftPublishRequest? body,
  }) => _remote.publishShift(id, body: body);

  Future<ShiftOut> patchShift(String shiftId, {required int workerCount}) =>
      _remote.patchShift(shiftId, ShiftPatchRequest(workerCount: workerCount));

  Future<ShiftOut> putParticipants(
    String shiftId,
    ShiftParticipantsReplaceRequest body,
  ) => _remote.putParticipants(shiftId, body);

  /// Soft-remove by client [participantId] (not shift_participant row id).
  Future<ShiftOut> removeParticipant(
    String shiftId,
    String participantId, {
    required String reason,
    String rebalance = 'equal',
  }) => _remote.removeParticipant(
    shiftId,
    participantId,
    reason: reason,
    rebalance: rebalance,
  );

  Future<List<AllocationChangeLogOut>> getAllocationChanges(String shiftId) =>
      _remote.getAllocationChanges(shiftId);

  Future<ShiftOut> assignShift({
    required String shiftId,
    required String contractorId,
    List<TaskTemplateItem>? taskTemplate,
  }) => _remote.assignShift(
    shiftId: shiftId,
    contractorId: contractorId,
    taskTemplate: taskTemplate,
  );

  Future<ShiftOut> assignShiftBatch({
    required String shiftId,
    required List<String> contractorIds,
    List<TaskTemplateItem>? taskTemplate,
  }) => _remote.assignShiftBatch(
    shiftId: shiftId,
    contractorIds: contractorIds,
    taskTemplate: taskTemplate,
  );

  Future<ShiftOut> unassignShift(String shiftId, String contractorId) =>
      _remote.unassignShift(shiftId, contractorId);

  Future<ShiftOut> claimShift(String id) => _remote.claimShift(id);

  Future<ShiftOut> cancelShift(String id) => _remote.cancelShift(id);
}
