/// Visits DTOs (design §6.8 / wiring guide §9).

/// Attached job form-catalog row (`GET /v1/jobs/{id}/form-catalog`).
class JobFormCatalogItem {
  const JobFormCatalogItem({
    required this.formTemplateId,
    required this.name,
    required this.isActive,
    this.clientId,
  });

  final String formTemplateId;
  final String name;
  final bool isActive;
  final String? clientId;

  factory JobFormCatalogItem.fromJson(Map<String, dynamic> json) {
    return JobFormCatalogItem(
      formTemplateId: json['form_template_id'].toString(),
      name: json['name'] as String? ?? 'Form',
      isActive: json['is_active'] as bool? ?? true,
      clientId: json['client_id']?.toString(),
    );
  }
}

class VisitTaskOut {
  const VisitTaskOut({
    required this.id,
    required this.visitId,
    required this.title,
    required this.sortOrder,
    required this.isDone,
    this.doneAt,
    this.tenantId,
  });

  final String id;
  final String? tenantId;
  final String visitId;
  final String title;
  final int sortOrder;
  final bool isDone;
  final DateTime? doneAt;

  factory VisitTaskOut.fromJson(Map<String, dynamic> json) {
    return VisitTaskOut(
      id: json['id'].toString(),
      tenantId: json['tenant_id']?.toString(),
      visitId: json['visit_id'].toString(),
      title: json['title'] as String? ?? '',
      sortOrder: json['sort_order'] as int? ?? 0,
      isDone: json['is_done'] as bool? ?? false,
      doneAt: json['done_at'] != null
          ? DateTime.tryParse(json['done_at'].toString())
          : null,
    );
  }

  VisitTaskOut copyWith({bool? isDone, DateTime? doneAt}) {
    return VisitTaskOut(
      id: id,
      tenantId: tenantId,
      visitId: visitId,
      title: title,
      sortOrder: sortOrder,
      isDone: isDone ?? this.isDone,
      doneAt: doneAt ?? this.doneAt,
    );
  }
}

class VisitFormRequirement {
  const VisitFormRequirement({
    required this.formTemplateId,
    this.isRequired = true,
    this.name,
    this.schemaJson = const {},
  });

  final String formTemplateId;
  final bool isRequired;
  final String? name;
  final Map<String, dynamic> schemaJson;

  List<VisitFormFieldSchema> get fields {
    final raw = schemaJson['fields'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => VisitFormFieldSchema.fromJson(Map<String, dynamic>.from(e)))
        .where((f) => f.id.isNotEmpty)
        .toList(growable: false);
  }

  factory VisitFormRequirement.fromJson(Map<String, dynamic> json) {
    final schema = json['schema_json'];
    return VisitFormRequirement(
      formTemplateId: (json['form_template_id'] ?? json['id']).toString(),
      isRequired: json['is_required'] as bool? ?? true,
      name: json['name'] as String? ?? json['form_template_name'] as String?,
      schemaJson: schema is Map
          ? Map<String, dynamic>.from(schema)
          : const <String, dynamic>{},
    );
  }
}

class VisitFormFieldSchema {
  const VisitFormFieldSchema({
    required this.id,
    required this.type,
    required this.label,
    required this.required,
    this.options = const [],
    this.section,
    this.accept = const [],
  });

  final String id;
  final String type;
  final String label;
  final bool required;
  final List<String> options;
  final String? section;
  final List<String> accept;

  factory VisitFormFieldSchema.fromJson(Map<String, dynamic> json) {
    final optionsRaw = json['options'];
    final acceptRaw = json['accept'];
    return VisitFormFieldSchema(
      id: (json['id'] ?? json['key'] ?? '').toString(),
      type: json['type'] as String? ?? 'text',
      label: json['label'] as String? ?? '',
      required: json['required'] as bool? ?? false,
      options: optionsRaw is List
          ? optionsRaw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
          : const <String>[],
      section: json['section']?.toString(),
      accept: acceptRaw is List
          ? acceptRaw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
          : const <String>[],
    );
  }
}

class VisitFormSubmissionOut {
  const VisitFormSubmissionOut({
    required this.id,
    required this.formTemplateId,
    this.payloadJson = const {},
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String formTemplateId;
  final Map<String, dynamic> payloadJson;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory VisitFormSubmissionOut.fromJson(Map<String, dynamic> json) {
    final payload = json['payload_json'];
    return VisitFormSubmissionOut(
      id: json['id'].toString(),
      formTemplateId: json['form_template_id'].toString(),
      payloadJson: payload is Map
          ? Map<String, dynamic>.from(payload)
          : const {},
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }
}

class VisitOut {
  const VisitOut({
    required this.id,
    required this.tenantId,
    required this.jobId,
    required this.contractorId,
    required this.scheduledStart,
    required this.scheduledEnd,
    required this.status,
    required this.source,
    required this.geofenceRadiusM,
    required this.geofenceMode,
    required this.paymentStatus,
    required this.createdAt,
    required this.updatedAt,
    this.recurrenceRuleId,
    this.latitude,
    this.longitude,
    this.completedAt,
    this.jobTitle,
    this.tenantName,
    this.contractorName,
    this.locationLabel,
    this.tasks = const [],
    this.formRequirements = const [],
    this.formSubmissions = const [],
  });

  final String id;
  final String tenantId;
  final String jobId;
  final String contractorId;
  final DateTime scheduledStart;
  final DateTime scheduledEnd;
  final String status; // scheduled | checked_in | completed | cancelled
  final String source;
  final String? recurrenceRuleId;
  final double? latitude;
  final double? longitude;
  final int geofenceRadiusM;
  final String geofenceMode;
  final String paymentStatus;
  final DateTime? completedAt;
  final String? jobTitle;
  final String? tenantName;
  final String? contractorName;
  final String? locationLabel;
  final List<VisitTaskOut> tasks;
  final List<VisitFormRequirement> formRequirements;
  final List<VisitFormSubmissionOut> formSubmissions;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isScheduled => status == 'scheduled';
  bool get isCheckedIn => status == 'checked_in';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  bool get geofenceEnforced =>
      geofenceMode == 'enforced' || geofenceMode == 'enforce';

  factory VisitOut.fromJson(Map<String, dynamic> json) {
    List<T> mapList<T>(Object? raw, T Function(Map<String, dynamic>) map) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => map(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    }

    return VisitOut(
      id: json['id'].toString(),
      tenantId: json['tenant_id'].toString(),
      jobId: json['job_id'].toString(),
      contractorId: json['contractor_id'].toString(),
      scheduledStart: DateTime.parse(json['scheduled_start'] as String),
      scheduledEnd: DateTime.parse(json['scheduled_end'] as String),
      status: json['status'] as String? ?? 'scheduled',
      source: json['source'] as String? ?? 'manual',
      recurrenceRuleId: json['recurrence_rule_id']?.toString(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      geofenceRadiusM: json['geofence_radius_m'] as int? ?? 100,
      geofenceMode: json['geofence_mode'] as String? ?? 'informational',
      paymentStatus: json['payment_status'] as String? ?? 'unpaid',
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'].toString())
          : null,
      jobTitle: json['job_title'] as String?,
      tenantName: json['tenant_name'] as String?,
      contractorName: json['contractor_name'] as String?,
      locationLabel: json['location_label'] as String?,
      tasks: mapList(json['tasks'], VisitTaskOut.fromJson),
      formRequirements: mapList(
        json['form_requirements'] ?? json['required_forms'],
        VisitFormRequirement.fromJson,
      ),
      formSubmissions: mapList(
        json['form_submissions'],
        VisitFormSubmissionOut.fromJson,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  VisitOut copyWith({
    String? status,
    DateTime? completedAt,
    List<VisitTaskOut>? tasks,
    List<VisitFormRequirement>? formRequirements,
    List<VisitFormSubmissionOut>? formSubmissions,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
  }) {
    return VisitOut(
      id: id,
      tenantId: tenantId,
      jobId: jobId,
      contractorId: contractorId,
      scheduledStart: scheduledStart ?? this.scheduledStart,
      scheduledEnd: scheduledEnd ?? this.scheduledEnd,
      status: status ?? this.status,
      source: source,
      recurrenceRuleId: recurrenceRuleId,
      latitude: latitude,
      longitude: longitude,
      geofenceRadiusM: geofenceRadiusM,
      geofenceMode: geofenceMode,
      paymentStatus: paymentStatus,
      completedAt: completedAt ?? this.completedAt,
      jobTitle: jobTitle,
      tenantName: tenantName,
      contractorName: contractorName,
      locationLabel: locationLabel,
      tasks: tasks ?? this.tasks,
      formRequirements: formRequirements ?? this.formRequirements,
      formSubmissions: formSubmissions ?? this.formSubmissions,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class VisitGpsBody {
  const VisitGpsBody({
    required this.lat,
    required this.lng,
    this.accuracyM,
  });

  final double lat;
  final double lng;
  final double? accuracyM;

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        if (accuracyM != null) 'accuracy_m': accuracyM,
      };
}

class VisitCheckInOut {
  const VisitCheckInOut({
    required this.visitId,
    required this.status,
    this.timeEntryId,
  });

  final String visitId;
  final String status;
  final String? timeEntryId;

  factory VisitCheckInOut.fromJson(Map<String, dynamic> json) {
    return VisitCheckInOut(
      visitId: json['visit_id'].toString(),
      status: json['status'] as String? ?? 'checked_in',
      timeEntryId: json['time_entry_id']?.toString(),
    );
  }
}

class VisitCompleteOut {
  const VisitCompleteOut({
    required this.visitId,
    required this.status,
    this.completedAt,
  });

  final String visitId;
  final String status;
  final DateTime? completedAt;

  factory VisitCompleteOut.fromJson(Map<String, dynamic> json) {
    return VisitCompleteOut(
      visitId: json['visit_id'].toString(),
      status: json['status'] as String? ?? 'completed',
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'].toString())
          : null,
    );
  }
}

class VisitFormSubmitRequest {
  const VisitFormSubmitRequest({
    required this.formTemplateId,
    required this.payloadJson,
  });

  final String formTemplateId;
  final Map<String, dynamic> payloadJson;

  Map<String, dynamic> toJson() => {
        'form_template_id': formTemplateId,
        'payload_json': payloadJson,
      };
}
