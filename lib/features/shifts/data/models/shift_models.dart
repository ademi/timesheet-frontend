/// Shift roster DTOs.

class ShiftAssignmentOut {
  const ShiftAssignmentOut({
    required this.id,
    required this.contractorId,
    required this.contractorName,
    required this.visitId,
    required this.source,
    required this.status,
  });

  final String id;
  final String contractorId;
  final String contractorName;
  final String visitId;
  final String source;
  final String status;

  factory ShiftAssignmentOut.fromJson(Map<String, dynamic> json) {
    return ShiftAssignmentOut(
      id: json['id'].toString(),
      contractorId: json['contractor_id'].toString(),
      contractorName: json['contractor_name'] as String? ?? 'Worker',
      visitId: json['visit_id'].toString(),
      source: json['source'] as String? ?? 'staff_assign',
      status: json['status'] as String? ?? 'active',
    );
  }
}

class ShiftOut {
  const ShiftOut({
    required this.id,
    required this.tenantId,
    required this.jobId,
    required this.jobTitle,
    this.clientId,
    this.clientName,
    required this.scheduledStart,
    required this.scheduledEnd,
    required this.requiredSlots,
    required this.openSlots,
    required this.status,
    this.locationLabel,
    this.suburb,
    this.postalCode,
    this.assignments = const [],
    this.publishedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String tenantId;
  final String jobId;
  final String jobTitle;
  final String? clientId;
  final String? clientName;
  final DateTime scheduledStart;
  final DateTime scheduledEnd;
  final int requiredSlots;
  final int openSlots;
  final String status;
  final String? locationLabel;
  final String? suburb;
  final String? postalCode;
  final List<ShiftAssignmentOut> assignments;
  final DateTime? publishedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get filledSlots => requiredSlots - openSlots;

  factory ShiftOut.fromJson(Map<String, dynamic> json) {
    return ShiftOut(
      id: json['id'].toString(),
      tenantId: json['tenant_id'].toString(),
      jobId: json['job_id'].toString(),
      jobTitle: json['job_title'] as String? ?? 'Shift',
      clientId: json['client_id']?.toString(),
      clientName: json['client_name'] as String?,
      scheduledStart: DateTime.parse(json['scheduled_start'] as String),
      scheduledEnd: DateTime.parse(json['scheduled_end'] as String),
      requiredSlots: json['required_slots'] as int? ?? 1,
      openSlots: json['open_slots'] as int? ?? 0,
      status: json['status'] as String? ?? 'draft',
      locationLabel: json['location_label'] as String?,
      suburb: json['suburb'] as String?,
      postalCode: json['postal_code'] as String?,
      assignments: (json['assignments'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => ShiftAssignmentOut.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'].toString())
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class OpenShiftOut {
  const OpenShiftOut({
    required this.id,
    required this.jobTitle,
    this.clientName,
    required this.scheduledStart,
    required this.scheduledEnd,
    required this.requiredSlots,
    required this.openSlots,
    this.suburb,
    this.postalCode,
  });

  final String id;
  final String jobTitle;
  final String? clientName;
  final DateTime scheduledStart;
  final DateTime scheduledEnd;
  final int requiredSlots;
  final int openSlots;
  final String? suburb;
  final String? postalCode;

  factory OpenShiftOut.fromJson(Map<String, dynamic> json) {
    return OpenShiftOut(
      id: json['id'].toString(),
      jobTitle: json['job_title'] as String? ?? 'Shift',
      clientName: json['client_name'] as String?,
      scheduledStart: DateTime.parse(json['scheduled_start'] as String),
      scheduledEnd: DateTime.parse(json['scheduled_end'] as String),
      requiredSlots: json['required_slots'] as int? ?? 1,
      openSlots: json['open_slots'] as int? ?? 0,
      suburb: json['suburb'] as String?,
      postalCode: json['postal_code'] as String?,
    );
  }
}

class ShiftCreateRequest {
  const ShiftCreateRequest({
    required this.jobId,
    required this.scheduledStart,
    required this.scheduledEnd,
    this.requiredSlots = 1,
    this.status = 'draft',
  });

  final String jobId;
  final DateTime scheduledStart;
  final DateTime scheduledEnd;
  final int requiredSlots;
  final String status;

  Map<String, dynamic> toJson() => {
        'job_id': jobId,
        'scheduled_start': scheduledStart.toUtc().toIso8601String(),
        'scheduled_end': scheduledEnd.toUtc().toIso8601String(),
        'required_slots': requiredSlots,
        'status': status,
      };
}
