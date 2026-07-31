import 'notification_display.dart';

/// Compliance ops DTOs (design §6.11).
const rightsRequestTypes = <String>[
  'access',
  'correction',
  'deletion',
  'export',
];

class RightsRequestOut {
  const RightsRequestOut({
    required this.id,
    required this.requestType,
    required this.status,
    required this.createdAt,
    this.notes,
    this.updatedAt,
  });

  final String id;
  final String requestType;
  final String status;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  factory RightsRequestOut.fromJson(Map<String, dynamic> json) {
    return RightsRequestOut(
      id: json['id'].toString(),
      requestType: json['request_type'] as String? ??
          json['type'] as String? ??
          'access',
      status: json['status'] as String? ?? 'submitted',
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(
        (json['created_at'] ?? DateTime.now().toUtc().toIso8601String())
            as String,
      ),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }
}

class RightsRequestCreate {
  const RightsRequestCreate({
    required this.requestType,
    this.notes,
  });

  final String requestType;
  final String? notes;

  Map<String, dynamic> toJson() => {
        'request_type': requestType,
        if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
      };
}

class AccessHistoryEntry {
  const AccessHistoryEntry({
    required this.id,
    required this.createdAt,
    this.actorLabel,
    this.action,
    this.resourceType,
    this.detail,
  });

  final String id;
  final DateTime createdAt;
  final String? actorLabel;
  final String? action;
  final String? resourceType;
  final String? detail;

  factory AccessHistoryEntry.fromJson(Map<String, dynamic> json) {
    return AccessHistoryEntry(
      id: (json['id'] ?? json['event_id'] ?? '').toString(),
      createdAt: DateTime.parse(
        (json['created_at'] ?? json['occurred_at'] ?? DateTime.now().toIso8601String())
            as String,
      ),
      actorLabel: json['actor_label'] as String? ??
          json['actor_email'] as String? ??
          json['user_email'] as String?,
      action: json['action'] as String? ?? json['event_type'] as String?,
      resourceType: json['resource_type'] as String?,
      detail: json['detail'] as String? ?? json['summary'] as String?,
    );
  }
}

class IncidentOut {
  const IncidentOut({
    required this.id,
    required this.title,
    required this.status,
    required this.createdAt,
    this.description,
    this.discoveredAt,
    this.assessmentDueAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String? description;
  final String status;
  final DateTime? discoveredAt;
  final DateTime? assessmentDueAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  /// Display-only NDB-style clock from API dates (no legal advice).
  String? get assessmentClockLabel {
    final due = assessmentDueAt;
    if (due == null) return null;
    final days = due.toUtc().difference(DateTime.now().toUtc()).inDays;
    if (days >= 0) {
      return 'Assessment due in ~$days day(s) (${due.toLocal().toIso8601String().substring(0, 10)})';
    }
    return 'Assessment due date passed (${due.toLocal().toIso8601String().substring(0, 10)})';
  }

  factory IncidentOut.fromJson(Map<String, dynamic> json) {
    DateTime? parseDt(Object? v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    return IncidentOut(
      id: json['id'].toString(),
      title: json['title'] as String? ?? 'Incident',
      description: json['description'] as String? ?? json['summary'] as String?,
      status: json['status'] as String? ?? 'open',
      discoveredAt: parseDt(json['discovered_at'] ?? json['occurred_at']),
      assessmentDueAt: parseDt(
        json['assessment_due_at'] ?? json['ndb_assessment_due_at'],
      ),
      createdAt: DateTime.parse(
        (json['created_at'] ?? DateTime.now().toIso8601String()) as String,
      ),
      updatedAt: parseDt(json['updated_at']),
    );
  }
}

class IncidentCreate {
  const IncidentCreate({
    required this.title,
    this.description,
    this.discoveredAt,
  });

  final String title;
  final String? description;
  final DateTime? discoveredAt;

  Map<String, dynamic> toJson() => {
        'title': title,
        if (description != null && description!.trim().isNotEmpty)
          'description': description!.trim(),
        if (discoveredAt != null)
          'discovered_at': discoveredAt!.toUtc().toIso8601String(),
      };
}

class PrivacyExportResult {
  const PrivacyExportResult({
    this.message,
    this.downloadUrl,
    this.raw = const {},
  });

  final String? message;
  final String? downloadUrl;
  final Map<String, dynamic> raw;

  factory PrivacyExportResult.fromJson(Map<String, dynamic> json) {
    return PrivacyExportResult(
      message: json['message'] as String? ?? json['status'] as String?,
      downloadUrl: json['download_url'] as String? ?? json['url'] as String?,
      raw: Map<String, dynamic>.from(json),
    );
  }
}

class NotificationEventOut {
  const NotificationEventOut({
    required this.id,
    required this.eventType,
    required this.createdAt,
    this.payload = const {},
  });

  final String id;
  final String eventType;
  final DateTime createdAt;
  final Map<String, dynamic> payload;

  factory NotificationEventOut.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'] ?? json['payload_json'];
    return NotificationEventOut(
      id: json['id'].toString(),
      eventType: json['event_type'] as String? ?? 'unknown',
      createdAt: DateTime.parse(
        (json['created_at'] ?? DateTime.now().toIso8601String()) as String,
      ),
      payload: payload is Map
          ? Map<String, dynamic>.from(payload)
          : const {},
    );
  }

  String get summary => notificationTitle(eventType, payload);
}

class SubscriptionStatusOut {
  const SubscriptionStatusOut({
    required this.status,
    this.planName,
    this.raw = const {},
  });

  final String status;
  final String? planName;
  final Map<String, dynamic> raw;

  bool get isActive =>
      status == 'active' || status == 'trialing' || status == 'ok';

  factory SubscriptionStatusOut.fromJson(Map<String, dynamic> json) {
    final nested = json['subscription'];
    final map = nested is Map
        ? Map<String, dynamic>.from(nested)
        : Map<String, dynamic>.from(json);
    return SubscriptionStatusOut(
      status: (map['status'] ?? json['status'] ?? 'unknown').toString(),
      planName: map['plan_name'] as String? ?? map['plan'] as String?,
      raw: map,
    );
  }
}

class TenantMemberOut {
  const TenantMemberOut({
    required this.id,
    required this.email,
    this.fullName,
    this.role,
  });

  final String id;
  final String email;
  final String? fullName;
  final String? role;

  factory TenantMemberOut.fromJson(Map<String, dynamic> json) {
    return TenantMemberOut(
      id: json['id'].toString(),
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String? ?? json['name'] as String?,
      role: json['role'] as String? ?? json['role_key'] as String?,
    );
  }
}
