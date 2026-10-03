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
    this.clientName,
    this.branchId,
    this.branchName,
    this.clientSiteId,
    this.clientSiteName,
    this.locationLabel,
    this.latitude,
    this.longitude,
    this.supportItemCode,
    this.supportItemName,
  });

  final String id;
  final String tenantId;
  final String? clientId;
  final String? clientName;
  final String kind; // standing | ad_hoc | program
  final String status; // open | closed | cancelled
  final String title;
  final String? branchId;
  final String? branchName;
  final String? clientSiteId;
  final String? clientSiteName;
  final String? locationLabel;
  final double? latitude;
  final double? longitude;
  final String? supportItemCode;
  final String? supportItemName;
  final int geofenceRadiusM;
  final String geofenceMode;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isOpen => status == 'open';
  bool get isStanding => kind == 'standing';
  bool get isProgram => kind == 'program';

  factory JobOut.fromJson(Map<String, dynamic> json) {
    return JobOut(
      id: json['id'].toString(),
      tenantId: json['tenant_id'].toString(),
      clientId: json['client_id']?.toString(),
      clientName: json['client_name'] as String?,
      kind: json['kind'] as String,
      status: json['status'] as String,
      title: json['title'] as String,
      branchId: json['branch_id']?.toString(),
      branchName: json['branch_name'] as String?,
      clientSiteId: json['client_site_id']?.toString(),
      clientSiteName: json['client_site_name'] as String?,
      locationLabel: json['location_label'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      supportItemCode: json['support_item_code'] as String?,
      supportItemName: json['support_item_name'] as String?,
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
    this.supportItemCode,
    this.supportItemName,
  });

  final String kind;
  final String title;
  final String? clientId;
  final String? branchId;
  final String? clientSiteId;
  final String? geofenceMode;
  final int? geofenceRadiusM;
  final String? supportItemCode;
  final String? supportItemName;

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'title': title,
    if (clientId != null) 'client_id': clientId,
    if (branchId != null) 'branch_id': branchId,
    if (clientSiteId != null) 'client_site_id': clientSiteId,
    if (geofenceMode != null) 'geofence_mode': geofenceMode,
    if (geofenceRadiusM != null) 'geofence_radius_m': geofenceRadiusM,
    if (supportItemCode != null) 'support_item_code': supportItemCode,
    if (supportItemName != null) 'support_item_name': supportItemName,
  };
}

class TaskTemplateItem {
  const TaskTemplateItem({
    required this.title,
    this.sortOrder = 0,
    this.supportItemCode,
  });

  final String title;
  final int sortOrder;
  final String? supportItemCode;

  factory TaskTemplateItem.fromJson(Map<String, dynamic> json) {
    return TaskTemplateItem(
      title: json['title'] as String? ?? '',
      sortOrder: json['sort_order'] as int? ?? 0,
      supportItemCode: json['support_item_code'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'sort_order': sortOrder,
    if (supportItemCode != null) 'support_item_code': supportItemCode,
  };
}

class RecurrenceParticipantIn {
  const RecurrenceParticipantIn({
    required this.participantId,
    this.allocationPct,
    this.supportItemCode,
  });

  final String participantId;
  final double? allocationPct;
  final String? supportItemCode;

  Map<String, dynamic> toJson() => {
    'participant_id': participantId,
    if (allocationPct != null) 'allocation_pct': allocationPct,
    if (supportItemCode != null) 'support_item_code': supportItemCode,
  };
}

class RecurrenceFormOverrideIn {
  const RecurrenceFormOverrideIn({
    required this.formTemplateId,
    required this.action,
    this.isRequired = true,
  });

  final String formTemplateId;
  final String action; // add | remove
  final bool isRequired;

  Map<String, dynamic> toJson() => {
    'form_template_id': formTemplateId,
    'action': action,
    'is_required': isRequired,
  };
}

class RecurrenceSegmentTemplateIn {
  const RecurrenceSegmentTemplateIn({
    required this.participantId,
    required this.anchorSupportItemCode,
    required this.offsetStartMinutes,
    required this.offsetEndMinutes,
    this.kind = 'direct',
    this.groupSize,
    this.notes,
    this.sortOrder = 0,
  });

  final String participantId;
  final String anchorSupportItemCode;
  final String kind;
  final int offsetStartMinutes;
  final int offsetEndMinutes;
  final int? groupSize;
  final String? notes;
  final int sortOrder;

  Map<String, dynamic> toJson() => {
    'participant_id': participantId,
    'anchor_support_item_code': anchorSupportItemCode,
    'kind': kind,
    'offset_start_minutes': offsetStartMinutes,
    'offset_end_minutes': offsetEndMinutes,
    if (groupSize != null) 'group_size': groupSize,
    if (notes != null) 'notes': notes,
    'sort_order': sortOrder,
  };
}

/// Place triad for A7 recurrence templates (mirrors shift place XOR).
class RecurrencePlaceIn {
  const RecurrencePlaceIn._({
    this.branchId,
    this.clientSiteId,
    this.label,
    this.latitude,
    this.longitude,
    this.postalCode,
    this.geofenceRadiusM,
  });

  const RecurrencePlaceIn.branch(String branchId)
    : this._(branchId: branchId);

  const RecurrencePlaceIn.clientSite(String clientSiteId)
    : this._(clientSiteId: clientSiteId);

  const RecurrencePlaceIn.labelled({
    required String label,
    required double latitude,
    required double longitude,
    required String postalCode,
    int? geofenceRadiusM,
  }) : this._(
         label: label,
         latitude: latitude,
         longitude: longitude,
         postalCode: postalCode,
         geofenceRadiusM: geofenceRadiusM,
       );

  final String? branchId;
  final String? clientSiteId;
  final String? label;
  final double? latitude;
  final double? longitude;
  final String? postalCode;
  final int? geofenceRadiusM;

  Map<String, dynamic> toJson() {
    if (branchId != null) return {'branch_id': branchId};
    if (clientSiteId != null) return {'client_site_id': clientSiteId};
    return {
      'label': label,
      'latitude': latitude,
      'longitude': longitude,
      'postal_code': postalCode,
      if (geofenceRadiusM != null) 'geofence_radius_m': geofenceRadiusM,
    };
  }
}

class RecurrenceRuleOut {
  const RecurrenceRuleOut({
    required this.id,
    required this.tenantId,
    required this.jobId,
    this.contractorIds = const [],
    required this.requiredSlots,
    this.workerCount = 1,
    this.publishPolicy = 'published',
    required this.rrule,
    required this.dtstart,
    required this.timeWindows,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.until,
    this.contractorNames = const [],
    this.taskTemplateJson = const [],
    this.formRequirementsJson = const [],
    this.formOverridesJson = const [],
    this.participantsJson = const [],
    this.segmentTemplateJson = const [],
    this.placeBranchId,
    this.placeClientSiteId,
    this.placeLabel,
    this.placePostalCode,
    this.latitude,
    this.longitude,
    this.geofenceRadiusMOverride,
    this.warnings = const [],
  });

  final String id;
  final String tenantId;
  final String jobId;
  final List<String> contractorIds;
  final int requiredSlots;
  final int workerCount;
  final String publishPolicy; // draft | published
  final List<String> contractorNames;
  final String rrule;
  final DateTime dtstart;
  final DateTime? until;
  final List<TimeWindow> timeWindows;
  final List<Map<String, dynamic>> taskTemplateJson;
  final List<Map<String, dynamic>> formRequirementsJson;
  final List<Map<String, dynamic>> formOverridesJson;
  final List<Map<String, dynamic>> participantsJson;
  final List<Map<String, dynamic>> segmentTemplateJson;
  final String? placeBranchId;
  final String? placeClientSiteId;
  final String? placeLabel;
  final String? placePostalCode;
  final double? latitude;
  final double? longitude;
  final int? geofenceRadiusMOverride;
  final List<String> warnings;
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

    List<String> stringList(Object? raw) {
      if (raw is! List) return const [];
      return raw.map((e) => e.toString()).toList(growable: false);
    }

    return RecurrenceRuleOut(
      id: json['id'].toString(),
      tenantId: json['tenant_id'].toString(),
      jobId: json['job_id'].toString(),
      contractorIds: stringList(json['contractor_ids']),
      requiredSlots: json['required_slots'] as int? ?? 1,
      workerCount: json['worker_count'] as int? ?? 1,
      publishPolicy: json['publish_policy'] as String? ?? 'published',
      contractorNames: stringList(json['contractor_names']),
      rrule: json['rrule'] as String,
      dtstart: DateTime.parse(json['dtstart'] as String),
      until:
          json['until'] != null
              ? DateTime.tryParse(json['until'].toString())
              : null,
      timeWindows: (json['time_windows_json'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => TimeWindow.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
      taskTemplateJson: mapList(json['task_template_json']),
      formRequirementsJson: mapList(json['form_requirements_json']),
      formOverridesJson: mapList(json['form_overrides_json']),
      participantsJson: mapList(json['participants_json']),
      segmentTemplateJson: mapList(json['segment_template_json']),
      placeBranchId: json['place_branch_id']?.toString(),
      placeClientSiteId: json['place_client_site_id']?.toString(),
      placeLabel: json['place_label'] as String?,
      placePostalCode: json['place_postal_code'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      geofenceRadiusMOverride: json['geofence_radius_m_override'] as int?,
      warnings: stringList(json['warnings']),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class RecurrenceRuleCreateRequest {
  const RecurrenceRuleCreateRequest({
    this.contractorIds = const [],
    this.requiredSlots = 1,
    this.workerCount = 1,
    this.publishPolicy = 'published',
    required this.rrule,
    required this.dtstart,
    required this.timeWindows,
    this.until,
    this.taskTitles = const [],
    this.taskTemplate = const [],
    this.formTemplateIds = const [],
    this.place,
    this.participants = const [],
    this.formOverrides = const [],
    this.segmentTemplate = const [],
  });

  /// Soft preferred contractors (A7/10C) — never auto-assigned on generate.
  final List<String> contractorIds;
  final int requiredSlots;
  final int workerCount;
  final String publishPolicy; // draft | published
  final String rrule;
  final DateTime dtstart;
  final DateTime? until;
  final List<TimeWindow> timeWindows;
  final List<String> taskTitles;
  final List<TaskTemplateItem> taskTemplate;
  final List<String> formTemplateIds;
  final RecurrencePlaceIn? place;
  final List<RecurrenceParticipantIn> participants;
  final List<RecurrenceFormOverrideIn> formOverrides;
  final List<RecurrenceSegmentTemplateIn> segmentTemplate;

  List<TaskTemplateItem> get _resolvedTaskTemplate {
    if (taskTemplate.isNotEmpty) return taskTemplate;
    return [
      for (var i = 0; i < taskTitles.length; i++)
        TaskTemplateItem(title: taskTitles[i], sortOrder: i),
    ];
  }

  Map<String, dynamic> toJson() => {
    'contractor_ids': contractorIds,
    'required_slots': requiredSlots,
    'worker_count': workerCount,
    'publish_policy': publishPolicy,
    'rrule': rrule,
    'dtstart': dtstart.toUtc().toIso8601String(),
    if (until != null) 'until': until!.toUtc().toIso8601String(),
    'time_windows': [for (final window in timeWindows) window.toJson()],
    'task_template': [for (final task in _resolvedTaskTemplate) task.toJson()],
    if (formTemplateIds.isNotEmpty)
      'form_requirements': [
        for (final id in formTemplateIds)
          {'form_template_id': id, 'is_required': true},
      ],
    if (place != null) 'place': place!.toJson(),
    'participants': [for (final p in participants) p.toJson()],
    'form_overrides': [for (final o in formOverrides) o.toJson()],
    'segment_template': [for (final s in segmentTemplate) s.toJson()],
  };
}

/// Partial update of a recurrence template (A7).
class RecurrenceRulePatchRequest {
  const RecurrenceRulePatchRequest({
    this.isActive,
    this.requiredSlots,
    this.workerCount,
    this.publishPolicy,
    this.timeWindows,
    this.taskTemplate,
    this.place,
    this.clearPlace = false,
    this.participants,
    this.formOverrides,
    this.segmentTemplate,
    this.contractorIds,
  });

  final bool? isActive;
  final int? requiredSlots;
  final int? workerCount;
  final String? publishPolicy;
  final List<TimeWindow>? timeWindows;
  final List<TaskTemplateItem>? taskTemplate;
  final RecurrencePlaceIn? place;
  final bool clearPlace;
  final List<RecurrenceParticipantIn>? participants;
  final List<RecurrenceFormOverrideIn>? formOverrides;
  final List<RecurrenceSegmentTemplateIn>? segmentTemplate;
  final List<String>? contractorIds;

  Map<String, dynamic> toJson() => {
    if (isActive != null) 'is_active': isActive,
    if (requiredSlots != null) 'required_slots': requiredSlots,
    if (workerCount != null) 'worker_count': workerCount,
    if (publishPolicy != null) 'publish_policy': publishPolicy,
    if (timeWindows != null)
      'time_windows': [for (final w in timeWindows!) w.toJson()],
    if (taskTemplate != null)
      'task_template': [for (final t in taskTemplate!) t.toJson()],
    if (place != null) 'place': place!.toJson(),
    if (clearPlace) 'clear_place': true,
    if (participants != null)
      'participants': [for (final p in participants!) p.toJson()],
    if (formOverrides != null)
      'form_overrides': [for (final o in formOverrides!) o.toJson()],
    if (segmentTemplate != null)
      'segment_template': [for (final s in segmentTemplate!) s.toJson()],
    if (contractorIds != null) 'contractor_ids': contractorIds,
  };
}

class TimeWindow {
  const TimeWindow({required this.startTime, required this.endTime});

  final String startTime;
  final String endTime;

  factory TimeWindow.fromJson(Map<String, dynamic> json) => TimeWindow(
    startTime: json['start_time'] as String,
    endTime: json['end_time'] as String,
  );

  Map<String, dynamic> toJson() => {
    'start_time': startTime,
    'end_time': endTime,
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
    this.createdShiftIds = const [],
    this.skipped = const [],
  });

  final List<String> createdVisitIds;
  final List<String> createdShiftIds;
  final List<GenerateVisitsConflict> skipped;

  factory GenerateVisitsResponse.fromJson(Map<String, dynamic> json) {
    final skippedRaw = json['skipped'];
    return GenerateVisitsResponse(
      createdVisitIds: (json['created_visit_ids'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      createdShiftIds: (json['created_shift_ids'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      skipped:
          skippedRaw is List
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

class HorizonRequest {
  const HorizonRequest({required this.from, required this.to, this.ruleIds});

  final DateTime from;
  final DateTime to;
  final List<String>? ruleIds;

  Map<String, dynamic> toJson() => {
    'from': from.toUtc().toIso8601String(),
    'to': to.toUtc().toIso8601String(),
    if (ruleIds != null) 'rule_ids': ruleIds,
  };
}

class HorizonOut {
  const HorizonOut({
    required this.createdShiftIds,
    required this.createdVisitIds,
    required this.skipped,
    required this.rulesProcessed,
    required this.truncated,
  });

  static const empty = HorizonOut(
    createdShiftIds: [],
    createdVisitIds: [],
    skipped: [],
    rulesProcessed: 0,
    truncated: false,
  );

  final List<String> createdShiftIds;
  final List<String> createdVisitIds;
  final List<GenerateVisitsConflict> skipped;
  final int rulesProcessed;
  final bool truncated;

  factory HorizonOut.fromJson(Map<String, dynamic> json) {
    final skippedRaw = json['skipped'];
    return HorizonOut(
      createdShiftIds: (json['created_shift_ids'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      createdVisitIds: (json['created_visit_ids'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      skipped:
          skippedRaw is List
              ? skippedRaw
                  .whereType<Map>()
                  .map(
                    (e) => GenerateVisitsConflict.fromJson(
                      Map<String, dynamic>.from(e),
                    ),
                  )
                  .toList(growable: false)
              : const [],
      rulesProcessed: json['rules_processed'] as int? ?? 0,
      truncated: json['truncated'] as bool? ?? false,
    );
  }
}

class OngoingSupportCreateRequest {
  const OngoingSupportCreateRequest({
    required this.clientId,
    required this.title,
    this.clientSiteId,
    this.branchId,
    this.contractorIds = const [],
    required this.rrule,
    required this.dtstart,
    this.until,
    this.requiredSlots = 1,
    required this.timeWindows,
    required this.horizonFrom,
    required this.horizonTo,
    this.supportItemCode,
    this.supportItemName,
    this.taskTemplate = const [],
  });

  final String clientId;
  final String title;
  final String? clientSiteId;
  final String? branchId;
  final List<String> contractorIds;
  final String rrule;
  final DateTime dtstart;
  final DateTime? until;
  final int requiredSlots;
  final List<TimeWindow> timeWindows;
  final DateTime horizonFrom;
  final DateTime horizonTo;
  final String? supportItemCode;
  final String? supportItemName;
  final List<TaskTemplateItem> taskTemplate;

  Map<String, dynamic> toJson() => {
    'client_id': clientId,
    'title': title,
    'client_site_id': clientSiteId,
    'branch_id': branchId,
    'contractor_ids': contractorIds,
    'rrule': rrule,
    'dtstart': dtstart.toUtc().toIso8601String(),
    if (until != null) 'until': until!.toUtc().toIso8601String(),
    'required_slots': requiredSlots,
    'time_windows': [for (final window in timeWindows) window.toJson()],
    'horizon_from': horizonFrom.toUtc().toIso8601String(),
    'horizon_to': horizonTo.toUtc().toIso8601String(),
    if (supportItemCode != null) 'support_item_code': supportItemCode,
    if (supportItemName != null) 'support_item_name': supportItemName,
    if (taskTemplate.isNotEmpty)
      'task_template': [for (final task in taskTemplate) task.toJson()],
  };
}

class OngoingSupportOut {
  const OngoingSupportOut({
    required this.job,
    required this.rule,
    required this.horizon,
  });

  final JobOut job;
  final RecurrenceRuleOut rule;
  final HorizonOut horizon;

  factory OngoingSupportOut.fromJson(Map<String, dynamic> json) {
    return OngoingSupportOut(
      job: JobOut.fromJson(Map<String, dynamic>.from(json['job'] as Map)),
      rule: RecurrenceRuleOut.fromJson(
        Map<String, dynamic>.from(json['rule'] as Map),
      ),
      horizon: HorizonOut.fromJson(
        Map<String, dynamic>.from(json['horizon'] as Map),
      ),
    );
  }
}

class SplitRecurrenceRequest {
  const SplitRecurrenceRequest({
    required this.fromDate,
    required this.timeWindows,
    this.contractorIds = const [],
    this.requiredSlots = 1,
    required this.horizonFrom,
    required this.horizonTo,
  });

  final DateTime fromDate;
  final List<TimeWindow> timeWindows;
  final List<String> contractorIds;
  final int requiredSlots;
  final DateTime horizonFrom;
  final DateTime horizonTo;

  Map<String, dynamic> toJson() => {
    'from_date':
        '${fromDate.year.toString().padLeft(4, '0')}-'
        '${fromDate.month.toString().padLeft(2, '0')}-'
        '${fromDate.day.toString().padLeft(2, '0')}',
    'time_windows': [for (final window in timeWindows) window.toJson()],
    'contractor_ids': contractorIds,
    'required_slots': requiredSlots,
    'horizon_from': horizonFrom.toUtc().toIso8601String(),
    'horizon_to': horizonTo.toUtc().toIso8601String(),
  };
}

class SplitRecurrenceOut {
  const SplitRecurrenceOut({
    required this.oldRule,
    required this.newRule,
    required this.horizon,
  });

  final RecurrenceRuleOut oldRule;
  final RecurrenceRuleOut newRule;
  final HorizonOut horizon;

  factory SplitRecurrenceOut.fromJson(Map<String, dynamic> json) {
    return SplitRecurrenceOut(
      oldRule: RecurrenceRuleOut.fromJson(
        Map<String, dynamic>.from(json['old_rule'] as Map),
      ),
      newRule: RecurrenceRuleOut.fromJson(
        Map<String, dynamic>.from(json['new_rule'] as Map),
      ),
      horizon: HorizonOut.fromJson(
        Map<String, dynamic>.from(json['horizon'] as Map),
      ),
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
    this.tasks = const [],
    this.formTemplateIds = const [],
    this.supportItemCode,
    this.supportItemName,
  });

  final String contractorId;
  final DateTime scheduledStart;
  final DateTime scheduledEnd;
  final List<String> taskTitles;
  final List<VisitTaskCreateItem> tasks;
  final List<String> formTemplateIds;
  final String? supportItemCode;
  final String? supportItemName;

  List<Map<String, dynamic>> get _taskJson {
    if (tasks.isNotEmpty) {
      return [for (final t in tasks) t.toJson()];
    }
    return [
      for (var i = 0; i < taskTitles.length; i++)
        {'title': taskTitles[i], 'sort_order': i},
    ];
  }

  Map<String, dynamic> toJson() => {
    'contractor_id': contractorId,
    'scheduled_start': scheduledStart.toUtc().toIso8601String(),
    'scheduled_end': scheduledEnd.toUtc().toIso8601String(),
    'tasks': _taskJson,
    'form_requirements': [
      for (final id in formTemplateIds)
        {'form_template_id': id, 'is_required': true},
    ],
    if (supportItemCode != null) 'support_item_code': supportItemCode,
    if (supportItemName != null) 'support_item_name': supportItemName,
  };
}

/// Task row on manual visit create (`POST /v1/jobs/{id}/visits`).
class VisitTaskCreateItem {
  const VisitTaskCreateItem({
    required this.title,
    this.sortOrder = 0,
    this.supportItemCode,
  });

  final String title;
  final int sortOrder;
  final String? supportItemCode;

  Map<String, dynamic> toJson() => {
    'title': title,
    'sort_order': sortOrder,
    if (supportItemCode != null) 'support_item_code': supportItemCode,
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
      schemaJson:
          schema is Map
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
  const BranchOut({required this.id, required this.name});

  final String id;
  final String name;

  factory BranchOut.fromJson(Map<String, dynamic> json) {
    return BranchOut(
      id: json['id'].toString(),
      name:
          (json['name'] as String?) ??
          (json['branch_name'] as String?) ??
          json['id'].toString(),
    );
  }
}

/// Minimal valid form schema for create (backend ALLOWED_FIELD_TYPES).
Map<String, dynamic> simpleTextFormSchema({
  String fieldId = 'notes',
  String label = 'Notes',
}) => {
  'fields': [
    {'id': fieldId, 'type': 'textarea', 'label': label, 'required': false},
  ],
};

/// Backend-allowed form field types for visit/job templates.
const formTemplateFieldTypes = <String>[
  'text',
  'textarea',
  'boolean',
  'number',
  'date',
  'file',
];

String formTemplateFieldTypeLabel(String type) => switch (type) {
  'text' => 'Short text',
  'textarea' => 'Long text',
  'boolean' => 'Yes / No',
  'number' => 'Number',
  'date' => 'Date',
  'file' => 'File upload',
  _ => type,
};

String slugifyFormFieldId(String label) {
  final slug = label
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return slug.isEmpty ? 'field' : slug;
}
