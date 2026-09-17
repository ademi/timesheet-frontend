import '../attendance_review_models.dart';
import '../datasources/attendance_remote_datasource.dart';

class AttendanceRepository {
  AttendanceRepository({required AttendanceRemoteDataSource remote})
    : _remote = remote;

  final AttendanceRemoteDataSource _remote;

  Future<List<AttendanceExceptionOut>> listExceptions({String? status}) =>
      _remote.listExceptions(status: status);

  Future<AttendanceExceptionOut> ackException(
    String exceptionId, {
    required String decision,
    String? note,
  }) => _remote.ackException(exceptionId, decision: decision, note: note);

  Future<List<AttendanceSyncConflictOut>> listSyncConflicts({
    String? status,
  }) => _remote.listSyncConflicts(status: status);

  Future<AttendanceSyncConflictOut> forceAcceptSyncConflict(
    String conflictId, {
    required String note,
  }) => _remote.forceAcceptSyncConflict(conflictId, note: note);

  Future<AttendanceSyncConflictOut> discardSyncConflict(
    String conflictId, {
    required String note,
  }) => _remote.discardSyncConflict(conflictId, note: note);

  /// Open GPS exceptions + sync conflicts for a visit (visit-detail deep link).
  Future<List<AttendanceReviewItem>> pendingForVisit(String visitId) async {
    final results = await Future.wait([
      listExceptions(status: 'pending_ack'),
      listSyncConflicts(status: 'open'),
    ]);
    final exceptions = results[0] as List<AttendanceExceptionOut>;
    final conflicts = results[1] as List<AttendanceSyncConflictOut>;
    final items = <AttendanceReviewItem>[
      for (final e in exceptions)
        if (e.visitId == visitId) AttendanceReviewItem.fromException(e),
      for (final c in conflicts)
        if (c.visitId == visitId) AttendanceReviewItem.fromSyncConflict(c),
    ]..sort((a, b) => b.sortAt.compareTo(a.sortAt));
    return items;
  }
}
