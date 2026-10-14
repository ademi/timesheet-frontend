// DTOs + unified review row for staff Attendance review (exceptions + sync conflicts).

import '../../../shared/utils/humanize_label.dart';

enum AttendanceReviewKind { exception, syncConflict }

enum AttendanceReviewFilter { all, gps, variance, sync }

/// Human labels for attendance exception kinds / reason codes (B5 variance report).
String attendanceExceptionHeadline(
  String kind,
  String reasonCode, {
  String? punchKind,
}) {
  switch (kind) {
    case 'geofence_outside':
      if (reasonCode == 'geofence_outside_clock_out' ||
          punchKind == 'clock_out') {
        return 'Clock-out outside geofence';
      }
      return 'Clock-in outside geofence';
    case 'early_clock_out':
      return 'Early clock-out';
    case 'late_check_in':
      return 'Late check-in';
    case 'location_missing':
      return 'GPS missing on punch';
    default:
      break;
  }
  final cleaned = reasonCode.trim();
  if (cleaned.isEmpty) return humanizeLabel(kind);
  return humanizeLabel(cleaned);
}

String attendanceExceptionDetail(String kind, String reasonCode) {
  final parts = <String>[humanizeLabel(kind)];
  final cleaned = reasonCode.trim();
  if (cleaned.isNotEmpty && cleaned != kind) {
    parts.add(humanizeLabel(cleaned));
  }
  return parts.join(' · ');
}

bool attendanceExceptionIsVariance(String kind) {
  return kind == 'geofence_outside' ||
      kind == 'early_clock_out' ||
      kind == 'late_check_in';
}

/// Display helper for geofence offset (BE returns meters).
String? formatGeofenceDistanceKm(num? distanceM) {
  if (distanceM == null) return null;
  final m = distanceM.toDouble();
  if (m.isNaN || m.isInfinite || m < 0) return null;
  if (m < 1000) {
    final rounded = m.round();
    return '$rounded m outside';
  }
  final km = m / 1000;
  final text = km >= 100 ? km.round().toString() : km.toStringAsFixed(1);
  return '$text km outside';
}

Map<String, dynamic>? _asStringKeyedMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return null;
}

class AttendanceVisitContext {
  const AttendanceVisitContext({
    required this.visitId,
    this.contractorId,
    this.contractorName,
    this.clientId,
    this.clientName,
    this.locationLabel,
    this.scheduledStart,
    this.scheduledEnd,
  });

  final String visitId;
  final String? contractorId;
  final String? contractorName;
  final String? clientId;
  final String? clientName;
  final String? locationLabel;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;

  factory AttendanceVisitContext.fromJson(Map<String, dynamic> json) {
    return AttendanceVisitContext(
      visitId: (json['visit_id'] ?? '').toString(),
      contractorId: json['contractor_id']?.toString(),
      contractorName: json['contractor_name'] as String?,
      clientId: json['client_id']?.toString(),
      clientName: json['client_name'] as String?,
      locationLabel: json['location_label'] as String?,
      scheduledStart:
          json['scheduled_start'] == null
              ? null
              : DateTime.tryParse(json['scheduled_start'].toString()),
      scheduledEnd:
          json['scheduled_end'] == null
              ? null
              : DateTime.tryParse(json['scheduled_end'].toString()),
    );
  }
}

class AttendanceGeofenceDetail {
  const AttendanceGeofenceDetail({
    this.distanceM,
    this.radiusM,
    this.punchLat,
    this.punchLng,
    this.siteLat,
    this.siteLng,
    this.nearestStopLabel,
    this.punchKind,
    this.punchAt,
  });

  final double? distanceM;
  final int? radiusM;
  final double? punchLat;
  final double? punchLng;
  final double? siteLat;
  final double? siteLng;
  final String? nearestStopLabel;
  final String? punchKind;
  final DateTime? punchAt;

  String? get distanceLabel => formatGeofenceDistanceKm(distanceM);

  factory AttendanceGeofenceDetail.fromJson(Map<String, dynamic> json) {
    return AttendanceGeofenceDetail(
      distanceM: (json['distance_m'] as num?)?.toDouble(),
      radiusM: (json['radius_m'] as num?)?.toInt(),
      punchLat: (json['punch_lat'] as num?)?.toDouble(),
      punchLng: (json['punch_lng'] as num?)?.toDouble(),
      siteLat: (json['site_lat'] as num?)?.toDouble(),
      siteLng: (json['site_lng'] as num?)?.toDouble(),
      nearestStopLabel: json['nearest_stop_label'] as String?,
      punchKind: json['punch_kind'] as String?,
      punchAt:
          json['punch_at'] == null
              ? null
              : DateTime.tryParse(json['punch_at'].toString()),
    );
  }
}

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
    this.visitContext,
    this.geofence,
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
  final AttendanceVisitContext? visitContext;
  final AttendanceGeofenceDetail? geofence;

  factory AttendanceExceptionOut.fromJson(Map<String, dynamic> json) {
    final visitCtx = _asStringKeyedMap(json['visit_context']);
    final geofence = _asStringKeyedMap(json['geofence']);
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
      visitContext:
          visitCtx == null ? null : AttendanceVisitContext.fromJson(visitCtx),
      geofence:
          geofence == null ? null : AttendanceGeofenceDetail.fromJson(geofence),
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
    this.visitContext,
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
  final AttendanceVisitContext? visitContext;

  factory AttendanceSyncConflictOut.fromJson(Map<String, dynamic> json) {
    final rawPayload = json['payload_json'];
    final visitCtx = _asStringKeyedMap(json['visit_context']);
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
      visitContext:
          visitCtx == null ? null : AttendanceVisitContext.fromJson(visitCtx),
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
    this.visitContext,
    this.geofence,
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
  final AttendanceVisitContext? visitContext;
  final AttendanceGeofenceDetail? geofence;

  factory AttendanceReviewItem.fromException(AttendanceExceptionOut e) {
    return AttendanceReviewItem(
      kind: AttendanceReviewKind.exception,
      id: e.id,
      visitId: e.visitId,
      status: e.status,
      sortAt: e.openedAt,
      headline: attendanceExceptionHeadline(
        e.kind,
        e.reasonCode,
        punchKind: e.geofence?.punchKind,
      ),
      detail: attendanceExceptionDetail(e.kind, e.reasonCode),
      exception: e,
      visitContext: e.visitContext,
      geofence: e.geofence,
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
      visitContext: c.visitContext,
    );
  }
}
