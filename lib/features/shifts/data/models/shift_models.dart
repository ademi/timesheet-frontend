import '../../../jobs/data/models/job_models.dart';
import 'shift_travel_models.dart';

/// Shift roster DTOs.

class ShiftAssignmentOut {
  const ShiftAssignmentOut({
    required this.id,
    required this.contractorId,
    required this.contractorName,
    required this.visitId,
    required this.source,
    required this.status,
    this.visitStatus,
    this.engagementId,
  });

  final String id;
  final String contractorId;
  final String contractorName;
  final String visitId;
  final String source;
  final String status;
  final String? visitStatus;
  final String? engagementId;

  factory ShiftAssignmentOut.fromJson(Map<String, dynamic> json) {
    return ShiftAssignmentOut(
      id: json['id'].toString(),
      contractorId: json['contractor_id'].toString(),
      contractorName: json['contractor_name'] as String? ?? 'Worker',
      visitId: json['visit_id'].toString(),
      source: json['source'] as String? ?? 'staff_assign',
      status: json['status'] as String? ?? 'active',
      visitStatus: json['visit_status'] as String?,
      engagementId: json['engagement_id']?.toString(),
    );
  }
}

/// Compact rate snapshot embedded on full participant outs.
class ShiftParticipantRateSnapshotSummary {
  const ShiftParticipantRateSnapshotSummary({
    required this.baseRate,
    this.supportItemCode,
    this.priceLimitNational,
    this.rateOverrideReason,
  });

  final String? supportItemCode;
  final double baseRate;
  final double? priceLimitNational;
  final String? rateOverrideReason;

  factory ShiftParticipantRateSnapshotSummary.fromJson(
    Map<String, dynamic> json,
  ) {
    return ShiftParticipantRateSnapshotSummary(
      supportItemCode: json['support_item_code'] as String?,
      baseRate: (json['base_rate'] as num).toDouble(),
      priceLimitNational: (json['price_limit_national'] as num?)?.toDouble(),
      rateOverrideReason: json['rate_override_reason'] as String?,
    );
  }
}

/// Time-based allocation window on a full participant out.
class ShiftParticipantAllocationOut {
  const ShiftParticipantAllocationOut({
    required this.id,
    required this.shiftParticipantId,
    required this.participantStartTime,
    required this.participantEndTime,
    required this.createdAt,
  });

  final String id;
  final String shiftParticipantId;
  final DateTime participantStartTime;
  final DateTime participantEndTime;
  final DateTime createdAt;

  factory ShiftParticipantAllocationOut.fromJson(Map<String, dynamic> json) {
    return ShiftParticipantAllocationOut(
      id: json['id'].toString(),
      shiftParticipantId: json['shift_participant_id'].toString(),
      participantStartTime: DateTime.parse(
        json['participant_start_time'] as String,
      ),
      participantEndTime: DateTime.parse(
        json['participant_end_time'] as String,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Shift participant row.
///
/// List (`include=participants_summary`) only fills [id], [participantId],
/// [participantName], [status]. Detail/mutation responses fill the rest.
class ShiftParticipantOut {
  const ShiftParticipantOut({
    required this.id,
    required this.participantId,
    required this.status,
    this.shiftId,
    this.allocationStrategy,
    this.allocationValue,
    this.participantName,
    this.rateSnapshot,
    this.timeWindows,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? shiftId;
  final String participantId;
  final String? allocationStrategy;
  final double? allocationValue;
  final String status;
  final String? participantName;
  final ShiftParticipantRateSnapshotSummary? rateSnapshot;
  final List<ShiftParticipantAllocationOut>? timeWindows;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ShiftParticipantOut.fromJson(Map<String, dynamic> json) {
    final rateRaw = json['rate_snapshot'];
    final windowsRaw = json['time_windows'];
    return ShiftParticipantOut(
      id: json['id'].toString(),
      shiftId: json['shift_id']?.toString(),
      participantId: json['participant_id'].toString(),
      allocationStrategy: json['allocation_strategy'] as String?,
      allocationValue: (json['allocation_value'] as num?)?.toDouble(),
      status: json['status'] as String? ?? 'active',
      participantName: json['participant_name'] as String?,
      rateSnapshot:
          rateRaw is Map
              ? ShiftParticipantRateSnapshotSummary.fromJson(
                Map<String, dynamic>.from(rateRaw),
              )
              : null,
      timeWindows:
          windowsRaw is List
              ? windowsRaw
                  .whereType<Map>()
                  .map(
                    (e) => ShiftParticipantAllocationOut.fromJson(
                      Map<String, dynamic>.from(e),
                    ),
                  )
                  .toList(growable: false)
              : null,
      createdAt:
          json['created_at'] != null
              ? DateTime.tryParse(json['created_at'].toString())
              : null,
      updatedAt:
          json['updated_at'] != null
              ? DateTime.tryParse(json['updated_at'].toString())
              : null,
    );
  }
}

/// Audit log entry for allocation changes.
class AllocationChangeLogOut {
  const AllocationChangeLogOut({
    required this.id,
    required this.shiftId,
    required this.changeType,
    required this.participantId,
    required this.changeReason,
    required this.createdAt,
    this.oldAllocationValue,
    this.newAllocationValue,
    this.oldAllocationStrategy,
    this.newAllocationStrategy,
    this.changedByUserId,
  });

  final String id;
  final String shiftId;
  final String changeType;
  final String participantId;
  final double? oldAllocationValue;
  final double? newAllocationValue;
  final String? oldAllocationStrategy;
  final String? newAllocationStrategy;
  final String changeReason;
  final String? changedByUserId;
  final DateTime createdAt;

  factory AllocationChangeLogOut.fromJson(Map<String, dynamic> json) {
    return AllocationChangeLogOut(
      id: json['id'].toString(),
      shiftId: json['shift_id'].toString(),
      changeType: json['change_type'] as String,
      participantId: json['participant_id'].toString(),
      oldAllocationValue: (json['old_allocation_value'] as num?)?.toDouble(),
      newAllocationValue: (json['new_allocation_value'] as num?)?.toDouble(),
      oldAllocationStrategy: json['old_allocation_strategy'] as String?,
      newAllocationStrategy: json['new_allocation_strategy'] as String?,
      changeReason: json['change_reason'] as String,
      changedByUserId: json['changed_by_user_id']?.toString(),
      createdAt: DateTime.parse(json['created_at'] as String),
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
    this.workerCount = 1,
    required this.status,
    this.recurrenceRuleId,
    this.locationLabel,
    this.suburb,
    this.postalCode,
    this.assignments = const [],
    this.participants = const [],
    this.travelClaims = const [],
    this.warnings = const [],
    this.accommodationSupportItemCode,
    this.accommodationQuantity,
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
  final int workerCount;
  final String status;
  final String? recurrenceRuleId;
  final String? locationLabel;
  final String? suburb;
  final String? postalCode;
  final List<ShiftAssignmentOut> assignments;
  final List<ShiftParticipantOut> participants;
  final List<ShiftTravelOut> travelClaims;
  final List<String> warnings;
  final String? accommodationSupportItemCode;
  final String? accommodationQuantity;
  final DateTime? publishedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get filledSlots => requiredSlots - openSlots;

  ShiftOut copyWith({List<ShiftTravelOut>? travelClaims}) {
    return ShiftOut(
      id: id,
      tenantId: tenantId,
      jobId: jobId,
      jobTitle: jobTitle,
      clientId: clientId,
      clientName: clientName,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      requiredSlots: requiredSlots,
      openSlots: openSlots,
      workerCount: workerCount,
      status: status,
      recurrenceRuleId: recurrenceRuleId,
      locationLabel: locationLabel,
      suburb: suburb,
      postalCode: postalCode,
      assignments: assignments,
      participants: participants,
      travelClaims: travelClaims ?? this.travelClaims,
      warnings: warnings,
      accommodationSupportItemCode: accommodationSupportItemCode,
      accommodationQuantity: accommodationQuantity,
      publishedAt: publishedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

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
      workerCount: json['worker_count'] as int? ?? 1,
      status: json['status'] as String? ?? 'draft',
      recurrenceRuleId: json['recurrence_rule_id']?.toString(),
      locationLabel: json['location_label'] as String?,
      suburb: json['suburb'] as String?,
      postalCode: json['postal_code'] as String?,
      assignments: (json['assignments'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => ShiftAssignmentOut.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
      participants: (json['participants'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (e) => ShiftParticipantOut.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(growable: false),
      travelClaims: (json['travel_claims'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => ShiftTravelOut.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
      warnings: (json['warnings'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      accommodationSupportItemCode:
          json['accommodation_support_item_code'] as String?,
      accommodationQuantity: json['accommodation_quantity']?.toString(),
      publishedAt:
          json['published_at'] != null
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

/// Input window for create / PUT replace (ISO datetimes).
class ShiftParticipantTimeWindowInput {
  const ShiftParticipantTimeWindowInput({
    required this.participantStartTime,
    required this.participantEndTime,
  });

  final DateTime participantStartTime;
  final DateTime participantEndTime;

  Map<String, dynamic> toJson() => {
    'participant_start_time': participantStartTime.toUtc().toIso8601String(),
    'participant_end_time': participantEndTime.toUtc().toIso8601String(),
  };
}

/// One participant in a composite create body (backend requires [reason]).
class ShiftParticipantCreateItem {
  const ShiftParticipantCreateItem({
    required this.participantId,
    required this.allocationStrategy,
    required this.reason,
    this.allocationValue,
    this.timeWindows,
  });

  final String participantId;
  final String allocationStrategy;
  final double? allocationValue;
  final String reason;
  final List<ShiftParticipantTimeWindowInput>? timeWindows;

  Map<String, dynamic> toJson() => {
    'participant_id': participantId,
    'allocation_strategy': allocationStrategy,
    if (allocationValue != null) 'allocation_value': allocationValue,
    'reason': reason,
    if (timeWindows != null && timeWindows!.isNotEmpty)
      'time_windows': [for (final w in timeWindows!) w.toJson()],
  };
}

/// One participant in a PUT replace-active-set body (Phase 1.1).
///
/// Strategy is top-level on [ShiftParticipantsReplaceRequest]; rows carry
/// values and optional [timeWindows] only.
class ShiftParticipantReplaceItem {
  const ShiftParticipantReplaceItem({
    required this.participantId,
    this.allocationValue,
    this.timeWindows,
  });

  final String participantId;
  final double? allocationValue;
  final List<ShiftParticipantTimeWindowInput>? timeWindows;

  Map<String, dynamic> toJson() => {
    'participant_id': participantId,
    if (allocationValue != null) 'allocation_value': allocationValue,
    if (timeWindows != null && timeWindows!.isNotEmpty)
      'time_windows': [for (final w in timeWindows!) w.toJson()],
  };
}

class ShiftParticipantsReplaceRequest {
  const ShiftParticipantsReplaceRequest({
    required this.participants,
    this.allocationStrategy = 'percentage',
    this.equalSplit = false,
  });

  final String allocationStrategy;
  final bool equalSplit;
  final List<ShiftParticipantReplaceItem> participants;

  Map<String, dynamic> toJson() => {
    'allocation_strategy': allocationStrategy,
    'equal_split': equalSplit,
    'participants': [for (final p in participants) p.toJson()],
  };
}

/// Per-participant support item and/or rate overrides at publish.
class ShiftParticipantPublishOverride {
  const ShiftParticipantPublishOverride({
    required this.participantId,
    this.supportItemCode,
    this.baseRate,
    this.saturdayRate,
    this.sundayRate,
    this.eveningRate,
    this.nightRate,
    this.publicHolidayRate,
    this.reason,
  });

  final String participantId;
  final String? supportItemCode;
  final double? baseRate;
  final double? saturdayRate;
  final double? sundayRate;
  final double? eveningRate;
  final double? nightRate;
  final double? publicHolidayRate;
  final String? reason;

  bool get hasAnyRate =>
      baseRate != null ||
      saturdayRate != null ||
      sundayRate != null ||
      eveningRate != null ||
      nightRate != null ||
      publicHolidayRate != null;

  Map<String, dynamic> toJson() => {
    'participant_id': participantId,
    if (supportItemCode != null && supportItemCode!.isNotEmpty)
      'support_item_code': supportItemCode,
    if (baseRate != null) 'base_rate': baseRate,
    if (saturdayRate != null) 'saturday_rate': saturdayRate,
    if (sundayRate != null) 'sunday_rate': sundayRate,
    if (eveningRate != null) 'evening_rate': eveningRate,
    if (nightRate != null) 'night_rate': nightRate,
    if (publicHolidayRate != null) 'public_holiday_rate': publicHolidayRate,
    if (reason != null && reason!.isNotEmpty) 'reason': reason,
  };
}

class ShiftPublishRequest {
  const ShiftPublishRequest({
    this.supportItemCode,
    this.participantOverrides,
    this.accommodationSupportItemCode,
    this.accommodationQuantity,
  });

  final String? supportItemCode;
  final List<ShiftParticipantPublishOverride>? participantOverrides;
  final String? accommodationSupportItemCode;
  final String? accommodationQuantity;

  Map<String, dynamic> toJson() => {
    if (supportItemCode != null && supportItemCode!.isNotEmpty)
      'support_item_code': supportItemCode,
    if (participantOverrides != null && participantOverrides!.isNotEmpty)
      'participant_overrides': [
        for (final o in participantOverrides!) o.toJson(),
      ],
    if (accommodationSupportItemCode != null &&
        accommodationSupportItemCode!.isNotEmpty)
      'accommodation_support_item_code': accommodationSupportItemCode,
    if (accommodationQuantity != null && accommodationQuantity!.isNotEmpty)
      'accommodation_quantity': accommodationQuantity,
  };
}

class ShiftPatchRequest {
  const ShiftPatchRequest({required this.workerCount});

  final int workerCount;

  Map<String, dynamic> toJson() => {'worker_count': workerCount};
}

class ShiftCreateRequest {
  const ShiftCreateRequest({
    required this.jobId,
    required this.scheduledStart,
    required this.scheduledEnd,
    this.requiredSlots = 1,
    this.workerCount = 1,
    this.status = 'draft',
    this.contractorIds = const [],
    this.taskTemplate = const [],
    this.equalSplit = false,
    this.participants = const [],
  });

  final String jobId;
  final DateTime scheduledStart;
  final DateTime scheduledEnd;
  final int requiredSlots;
  final int workerCount;
  final String status;
  final List<String> contractorIds;
  final List<TaskTemplateItem> taskTemplate;
  final bool equalSplit;
  final List<ShiftParticipantCreateItem> participants;

  Map<String, dynamic> toJson() => {
    'job_id': jobId,
    'scheduled_start': scheduledStart.toUtc().toIso8601String(),
    'scheduled_end': scheduledEnd.toUtc().toIso8601String(),
    'required_slots': requiredSlots,
    'worker_count': workerCount,
    'status': status,
    if (contractorIds.isNotEmpty) 'contractor_ids': contractorIds,
    if (taskTemplate.isNotEmpty)
      'task_template': [for (final t in taskTemplate) t.toJson()],
    if (equalSplit) 'equal_split': equalSplit,
    if (participants.isNotEmpty)
      'participants': [for (final p in participants) p.toJson()],
  };
}
