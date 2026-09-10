import '../datasources/shifts_remote_datasource.dart';
import '../models/shift_models.dart';
import '../models/shift_participant_models.dart';

class ShiftsRepository {
  ShiftsRepository({required ShiftsRemoteDataSource remote}) : _remote = remote;

  final ShiftsRemoteDataSource _remote;

  Future<List<ShiftOut>> listShifts({
    DateTime? from,
    DateTime? to,
    String? jobId,
  }) =>
      _remote.listShifts(from: from, to: to, jobId: jobId);

  Future<List<OpenShiftOut>> listOpenShifts({
    DateTime? from,
    DateTime? to,
  }) =>
      _remote.listOpenShifts(from: from, to: to);

  Future<ShiftOut> getShift(String id) => _remote.getShift(id);

  Future<ShiftOut> createShift(ShiftCreateRequest body) =>
      _remote.createShift(body);

  Future<ShiftOut> publishShift(String id) => _remote.publishShift(id);

  Future<ShiftOut> assignShift({
    required String shiftId,
    required String contractorId,
  }) =>
      _remote.assignShift(shiftId: shiftId, contractorId: contractorId);

  Future<ShiftOut> unassignShift(String shiftId, String contractorId) =>
      _remote.unassignShift(shiftId, contractorId);

  Future<ShiftOut> claimShift(String id) => _remote.claimShift(id);

  Future<ShiftOut> cancelShift(String id) => _remote.cancelShift(id);

  Future<ShiftOut> addParticipant({
    required String shiftId,
    required ShiftParticipantCreateRequest body,
  }) =>
      _remote.addParticipant(shiftId: shiftId, body: body);

  Future<ShiftOut> addParticipantsBatch({
    required String shiftId,
    required ShiftParticipantBatchCreateRequest body,
  }) =>
      _remote.addParticipantsBatch(shiftId: shiftId, body: body);

  Future<ShiftOut> removeParticipant({
    required String shiftId,
    required String participantId,
    required String reason,
  }) =>
      _remote.removeParticipant(
        shiftId: shiftId,
        participantId: participantId,
        reason: reason,
      );

  Future<ShiftOut> updateParticipantAllocation({
    required String shiftId,
    required String participantId,
    required ShiftParticipantAllocationUpdateRequest body,
  }) =>
      _remote.updateParticipantAllocation(
        shiftId: shiftId,
        participantId: participantId,
        body: body,
      );

  Future<List<AllocationChangeLogOut>> listAllocationChanges(String shiftId) =>
      _remote.listAllocationChanges(shiftId);
}
