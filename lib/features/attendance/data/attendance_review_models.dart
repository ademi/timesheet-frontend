// DTOs + unified review row for staff Attendance review (exceptions + sync conflicts).

enum AttendanceReviewKind { exception, syncConflict }

enum AttendanceReviewFilter { all, gps, sync }

class AttendanceExceptionOut {
  const AttendanceExceptionOut({
    required this.id,
    required this.tenantId,
    required this.visitId,
    required this.kind,
    required this.reasonCode,
    required this.status,
    required this.openedAt,
    this.timeEntryId,
    this.resolvedAt,
    this.resolvedByUserId,
    this.resolutionNote,
  });

  final String id;
  final String tenantId;
  final String visitId;
  final String? timeEntryId;
  final String kind;
  final String reasonCode;
  final String status;
  final DateTime openedAt;
  final DateTime? resolvedAt;
  final String? resolvedByUserId;
  final String? resolutionNote;

  factory AttendanceExceptionOut.fromJson(Map<String, dynamic> json) {
    return AttendanceExceptionOut(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      visitId: json['visit_id'] as String,
      timeEntryId: json['time_entry_id'] as String?,
      kind: json['kind'] as String,
      reasonCode: json['reason_code'] as String,
      status: json['status'] as String,
      openedAt: DateTime.parse(json['opened_at'] as String),
      resolvedAt:
          json['resolved_at'] == null
              ? null
              : DateTime.parse(json['resolved_at'] as String),
      resolvedByUserId: json['resolved_by_user_id'] as String?,
      resolutionNote: json['resolution_note'] as String?,
    );
  }
}

class AttendanceSyncConflictOut {
  const AttendanceSyncConflictOut({
    required this.id,
    required this.tenantId,
    required this.visitId,
    required this.contractorId,
    required this.clientEventId,
    required this.kind,
    required this.failureDetail,
    required this.payloadJson,
    required this.status,
    required this.createdAt,
    this.resolvedAt,
    this.resolvedByUserId,
    this.resolutionNote,
  });

  final String id;
  final String tenantId;
  final String visitId;
  final String contractorId;
  final String clientEventId;
  final String kind;
  final String failureDetail;
  final Map<String, dynamic> payloadJson;
  final String status;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? resolvedByUserId;
  final String? resolutionNote;

  factory AttendanceSyncConflictOut.fromJson(Map<String, dynamic> json) {
    final rawPayload = json['payload_json'];
    return AttendanceSyncConflictOut(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      visitId: json['visit_id'] as String,
      contractorId: json['contractor_id'] as String,
      clientEventId: json['client_event_id'] as String,
      kind: json['kind'] as String,
      failureDetail: json['failure_detail'] as String,
      payloadJson:
          rawPayload is Map<String, dynamic>
              ? rawPayload
              : rawPayload is Map
              ? Map<String, dynamic>.from(rawPayload)
              : const {},
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      resolvedAt:
          json['resolved_at'] == null
              ? null
              : DateTime.parse(json['resolved_at'] as String),
      resolvedByUserId: json['resolved_by_user_id'] as String?,
      resolutionNote: json['resolution_note'] as String?,
    );
  }
}

/// Unified inbox row for staff Attendance review.
class AttendanceReviewItem {
  const AttendanceReviewItem({
    required this.kind,
    required this.id,
    required this.visitId,
    required this.status,
    required this.sortAt,
    required this.headline,
    required this.detail,
    this.exception,
    this.syncConflict,
  });

  final AttendanceReviewKind kind;
  final String id;
  final String visitId;
  final String status;
  final DateTime sortAt;
  final String headline;
  final String detail;
  final AttendanceExceptionOut? exception;
  final AttendanceSyncConflictOut? syncConflict;

  factory AttendanceReviewItem.fromException(AttendanceExceptionOut e) {
    return AttendanceReviewItem(
      kind: AttendanceReviewKind.exception,
      id: e.id,
      visitId: e.visitId,
      status: e.status,
      sortAt: e.openedAt,
      headline: e.reasonCode,
      detail: e.kind,
      exception: e,
    );
  }

  factory AttendanceReviewItem.fromSyncConflict(AttendanceSyncConflictOut c) {
    return AttendanceReviewItem(
      kind: AttendanceReviewKind.syncConflict,
      id: c.id,
      visitId: c.visitId,
      status: c.status,
      sortAt: c.createdAt,
      headline: c.failureDetail,
      detail: c.kind,
      syncConflict: c,
    );
  }
}
