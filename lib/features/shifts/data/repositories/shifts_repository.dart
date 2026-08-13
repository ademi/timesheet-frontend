import '../datasources/shifts_remote_datasource.dart';
import '../models/shift_models.dart';

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

  Future<ShiftOut> claimShift(String id) => _remote.claimShift(id);

  Future<ShiftOut> cancelShift(String id) => _remote.cancelShift(id);
}
