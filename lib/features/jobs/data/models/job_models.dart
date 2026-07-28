/// Jobs, recurrence, and form-template DTOs (design §6.7).
class JobOut {
  const JobOut({
    required this.id,
    required this.tenantId,
    required this.kind,
    required this.status,
    required this.title,
    required this.geofenceRadiusM,
    required this.geofenceMode,
    required this.createdAt,
    required this.updatedAt,
    this.clientId,
    this.branchId,
    this.clientSiteId,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String tenantId;
  final String? clientId;
  final String kind; // standing | ad_hoc
  final String status; // open | closed | cancelled
  final String title;
  final String? branchId;
  final String? clientSiteId;
  final double? latitude;
  final double? longitude;
  final int geofenceRadiusM;
  final String geofenceMode;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isOpen => status == 'open';
  bool get isStanding => kind == 'standing';

  factory JobOut.fromJson(Map<String, dynamic> json) {
    return JobOut(
      id: json['id'].toString(),
      tenantId: json['tenant_id'].toString(),
      clientId: json['client_id']?.toString(),
      kind: json['kind'] as String,
      status: json['status'] as String,
      title: json['title'] as String,
      branchId: json['branch_id']?.toString(),
      clientSiteId: json['client_site_id']?.toString(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      geofenceRadiusM: json['geofence_radius_m'] as int? ?? 100,
      geofenceMode: json['geofence_mode'] as String? ?? 'informational',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

/// Attached form template on a job (`GET /v1/jobs/{id}/form-catalog`).
class JobFormCatalogOut {
  const JobFormCatalogOut({
    required this.formTemplateId,
    required this.name,
    required this.isActive,
    this.clientId,
  });

  final String formTemplateId;
  final String name;
  final bool isActive;
  final String? clientId;

  factory JobFormCatalogOut.fromJson(Map<String, dynamic> json) {
    return JobFormCatalogOut(
      formTemplateId: json['form_template_id'].toString(),
      name: json['name'] as String? ?? 'Form',
      isActive: json['is_active'] as bool? ?? true,
      clientId: json['client_id']?.toString(),
    );
  }
}

class JobCreateRequest {
  const JobCreateRequest({
    required this.kind,
    required this.title,
    this.clientId,
    this.branchId,
    this.clientSiteId,
    this.geofenceMode,
    this.geofenceRadiusM,
  });

  final String kind;
  final String title;
  final String? clientId;
  final String? branchId;
  final String? clientSiteId;
  final String? geofenceMode;
  final int? geofenceRadiusM;

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'title': title,
        if (clientId != null) 'client_id': clientId,
        if (branchId != null) 'branch_id': branchId,
        if (clientSiteId != null) 'client_site_id': clientSiteId,
        if (geofenceMode != null) 'geofence_mode': geofenceMode,
        if (geofenceRadiusM != null) 'geofence_radius_m': geofenceRadiusM,
      };
}

class RecurrenceRuleOut {
  const RecurrenceRuleOut({
    required this.id,
    required this.tenantId,
    required this.jobId,
    required this.contractorId,
    required this.rrule,
    required this.dtstart,
    required this.durationMinutes,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.until,
    this.taskTemplateJson = const [],
    this.formRequirementsJson = const [],
    this.latitude,
    this.longitude,
    this.geofenceRadiusMOverride,
  });

  final String id;
  final String tenantId;
  final String jobId;
  final String contractorId;
  final String rrule;
  final DateTime dtstart;
  final DateTime? until;
  final int durationMinutes;
  final List<Map<String, dynamic>> taskTemplateJson;
  final List<Map<String, dynamic>> formRequirementsJson;
  final double? latitude;
  final double? longitude;
  final int? geofenceRadiusMOverride;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory RecurrenceRuleOut.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> mapList(Object? raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    }

    return RecurrenceRuleOut(
      id: json['id'].toString(),
      tenantId: json['tenant_id'].toString(),
      jobId: json['job_id'].toString(),
      contractorId: json['contractor_id'].toString(),
      rrule: json['rrule'] as String,
      dtstart: DateTime.parse(json['dtstart'] as String),
      until: json['until'] != null
          ? DateTime.tryParse(json['until'].toString())
          : null,
      durationMinutes: json['duration_minutes'] as int,
      taskTemplateJson: mapList(json['task_template_json']),
      formRequirementsJson: mapList(json['form_requirements_json']),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      geofenceRadiusMOverride: json['geofence_radius_m_override'] as int?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class RecurrenceRuleCreateRequest {
  const RecurrenceRuleCreateRequest({
    required this.contractorId,
    required this.rrule,
    required this.dtstart,
    required this.durationMinutes,
    this.until,
    this.taskTitles = const [],
    this.formTemplateIds = const [],
  });

  final String contractorId;
  final String rrule;
  final DateTime dtstart;
  final DateTime? until;
  final int durationMinutes;
  final List<String> taskTitles;
  final List<String> formTemplateIds;

  Map<String, dynamic> toJson() => {
        'contractor_id': contractorId,
        'rrule': rrule,
        'dtstart': dtstart.toUtc().toIso8601String(),
        if (until != null) 'until': until!.toUtc().toIso8601String(),
        'duration_minutes': durationMinutes,
        'task_template': [
          for (var i = 0; i < taskTitles.length; i++)
            {'title': taskTitles[i], 'sort_order': i},
        ],
        'form_requirements': [
          for (final id in formTemplateIds)
            {'form_template_id': id, 'is_required': true},
        ],
      };
}

class GenerateVisitsRequest {
  const GenerateVisitsRequest({
    required this.from,
    required this.to,
    this.partial = false,
  });

  final DateTime from;
  final DateTime to;
  final bool partial;

  Map<String, dynamic> toJson() => {
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
        'partial': partial,
      };
}

class GenerateVisitsResponse {
  const GenerateVisitsResponse({
    required this.createdVisitIds,
    this.skipped = const [],
  });

  final List<String> createdVisitIds;
  final List<GenerateVisitsConflict> skipped;

  factory GenerateVisitsResponse.fromJson(Map<String, dynamic> json) {
    final skippedRaw = json['skipped'];
    return GenerateVisitsResponse(
      createdVisitIds: (json['created_visit_ids'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      skipped: skippedRaw is List
          ? skippedRaw
              .whereType<Map>()
              .map(
                (e) => GenerateVisitsConflict.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList(growable: false)
          : const [],
    );
  }
}

class GenerateVisitsConflict {
  const GenerateVisitsConflict({
    required this.scheduledStart,
    required this.detail,
  });

  final DateTime scheduledStart;
  final String detail;

  factory GenerateVisitsConflict.fromJson(Map<String, dynamic> json) {
    return GenerateVisitsConflict(
      scheduledStart: DateTime.parse(json['scheduled_start'] as String),
      detail: json['detail'] as String? ?? '',
    );
  }
}

class ManualVisitCreateRequest {
  const ManualVisitCreateRequest({
    required this.contractorId,
    required this.scheduledStart,
    required this.scheduledEnd,
    this.taskTitles = const [],
  });

  final String contractorId;
  final DateTime scheduledStart;
  final DateTime scheduledEnd;
  final List<String> taskTitles;

  Map<String, dynamic> toJson() => {
        'contractor_id': contractorId,
        'scheduled_start': scheduledStart.toUtc().toIso8601String(),
        'scheduled_end': scheduledEnd.toUtc().toIso8601String(),
        'tasks': [
          for (var i = 0; i < taskTitles.length; i++)
            {'title': taskTitles[i], 'sort_order': i},
        ],
      };
}

class FormTemplateOut {
  const FormTemplateOut({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.schemaJson,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.clientId,
  });

  final String id;
  final String tenantId;
  final String? clientId;
  final String name;
  final Map<String, dynamic> schemaJson;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory FormTemplateOut.fromJson(Map<String, dynamic> json) {
    final schema = json['schema_json'];
    return FormTemplateOut(
      id: json['id'].toString(),
      tenantId: json['tenant_id'].toString(),
      clientId: json['client_id']?.toString(),
      name: json['name'] as String? ?? json['name']?.toString() ?? '',
      schemaJson: schema is Map
          ? Map<String, dynamic>.from(schema)
          : const <String, dynamic>{},
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class FormTemplateCreateRequest {
  const FormTemplateCreateRequest({
    required this.name,
    required this.schemaJson,
    this.clientId,
    this.isActive = true,
  });

  final String name;
  final Map<String, dynamic> schemaJson;
  final String? clientId;
  final bool isActive;

  Map<String, dynamic> toJson() => {
        'name': name,
        'schema_json': schemaJson,
        if (clientId != null) 'client_id': clientId,
        'is_active': isActive,
      };
}

class BranchOut {
  const BranchOut({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;

  factory BranchOut.fromJson(Map<String, dynamic> json) {
    return BranchOut(
      id: json['id'].toString(),
      name: (json['name'] as String?) ??
          (json['branch_name'] as String?) ??
          json['id'].toString(),
    );
  }
}

/// Minimal valid form schema for create (backend ALLOWED_FIELD_TYPES).
Map<String, dynamic> simpleTextFormSchema({
  String fieldId = 'notes',
  String label = 'Notes',
}) =>
    {
      'fields': [
        {
          'id': fieldId,
          'type': 'textarea',
          'label': label,
          'required': false,
        },
      ],
    };
