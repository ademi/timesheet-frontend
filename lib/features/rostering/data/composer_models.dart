import '../../shifts/data/models/shift_models.dart';
import '../../visits/data/models/roster_overlay_models.dart';

/// Form override row on a draft shift (`GET/PUT …/form-overrides`).
class ShiftFormOverrideOut {
  const ShiftFormOverrideOut({
    required this.formTemplateId,
    required this.action,
    required this.isRequired,
    required this.name,
    required this.isActive,
  });

  final String formTemplateId;
  final String action; // add | remove
  final bool isRequired;
  final String name;
  final bool isActive;

  factory ShiftFormOverrideOut.fromJson(Map<String, dynamic> json) {
    return ShiftFormOverrideOut(
      formTemplateId: json['form_template_id'].toString(),
      action: json['action'] as String? ?? 'add',
      isRequired: json['is_required'] as bool? ?? true,
      name: json['name'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'form_template_id': formTemplateId,
    'action': action,
    'is_required': isRequired,
  };
}

/// Resolved form chip for composer hydrate / preview.
class ResolvedFormPreviewOut {
  const ResolvedFormPreviewOut({
    required this.formTemplateId,
    required this.name,
    required this.isRequired,
    required this.source,
  });

  final String formTemplateId;
  final String name;
  final bool isRequired;
  final String source; // org | client | override

  factory ResolvedFormPreviewOut.fromJson(Map<String, dynamic> json) {
    return ResolvedFormPreviewOut(
      formTemplateId: json['form_template_id'].toString(),
      name: json['name'] as String? ?? '',
      isRequired: json['is_required'] as bool? ?? true,
      source: json['source'] as String? ?? 'org',
    );
  }
}

/// Thin aggregate from `GET …/composer` and `POST …/copy`.
class ComposerShiftOut {
  const ComposerShiftOut({
    required this.shift,
    this.formOverrides = const [],
    this.resolvedFormsPreview = const [],
    this.segmentsByVisit = const {},
  });

  final ShiftOut shift;
  final List<ShiftFormOverrideOut> formOverrides;
  final List<ResolvedFormPreviewOut> resolvedFormsPreview;
  final Map<String, List<Map<String, dynamic>>> segmentsByVisit;

  factory ComposerShiftOut.fromJson(Map<String, dynamic> json) {
    final segmentsRaw = json['segments_by_visit'];
    final segments = <String, List<Map<String, dynamic>>>{};
    if (segmentsRaw is Map) {
      for (final entry in segmentsRaw.entries) {
        final list = entry.value;
        if (list is! List) continue;
        segments[entry.key.toString()] = [
          for (final row in list)
            if (row is Map) Map<String, dynamic>.from(row),
        ];
      }
    }

    return ComposerShiftOut(
      shift: ShiftOut.fromJson(Map<String, dynamic>.from(json['shift'] as Map)),
      formOverrides: (json['form_overrides'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (e) => ShiftFormOverrideOut.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(growable: false),
      resolvedFormsPreview: (json['resolved_forms_preview'] as List? ??
              const [])
          .whereType<Map>()
          .map(
            (e) =>
                ResolvedFormPreviewOut.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(growable: false),
      segmentsByVisit: segments,
    );
  }
}

class ShiftCopyRequest {
  const ShiftCopyRequest({
    required this.scheduledStart,
    required this.scheduledEnd,
    this.status = 'draft',
  });

  final DateTime scheduledStart;
  final DateTime scheduledEnd;
  final String status;

  Map<String, dynamic> toJson() => {
    'scheduled_start': scheduledStart.toUtc().toIso8601String(),
    'scheduled_end': scheduledEnd.toUtc().toIso8601String(),
    'status': status,
  };
}

class FormPreviewOverrideIn {
  const FormPreviewOverrideIn({
    required this.formTemplateId,
    required this.action,
    this.isRequired = true,
  });

  final String formTemplateId;
  final String action;
  final bool isRequired;

  Map<String, dynamic> toJson() => {
    'form_template_id': formTemplateId,
    'action': action,
    'is_required': isRequired,
  };
}

class FormPreviewRequirementsRequest {
  const FormPreviewRequirementsRequest({
    required this.jobId,
    this.shiftId,
    this.participantIds = const [],
    this.overrides,
  });

  final String jobId;
  final String? shiftId;
  final List<String> participantIds;
  final List<FormPreviewOverrideIn>? overrides;

  Map<String, dynamic> toJson() => {
    'job_id': jobId,
    if (shiftId != null && shiftId!.isNotEmpty) 'shift_id': shiftId,
    'participant_ids': participantIds,
    if (overrides != null) 'overrides': [for (final o in overrides!) o.toJson()],
  };
}

class PlaceBranchOption {
  const PlaceBranchOption({
    required this.id,
    required this.name,
    this.location,
    this.addressLine1,
    this.city,
    this.state,
    this.country,
    this.postalCode,
    this.latitude,
    this.longitude,
    this.geofenceRadiusM,
  });

  final String id;
  final String name;
  final String? location;
  final String? addressLine1;
  final String? city;
  final String? state;
  final String? country;
  final String? postalCode;
  final double? latitude;
  final double? longitude;
  final int? geofenceRadiusM;

  String get displayAddress {
    final parts = <String>[
      if (addressLine1 != null && addressLine1!.trim().isNotEmpty)
        addressLine1!.trim(),
      if (city != null && city!.trim().isNotEmpty) city!.trim(),
      if (state != null && state!.trim().isNotEmpty) state!.trim(),
      if (postalCode != null && postalCode!.trim().isNotEmpty)
        postalCode!.trim(),
      if (country != null && country!.trim().isNotEmpty) country!.trim(),
    ];
    if (parts.isNotEmpty) return parts.join(', ');
    final loc = location?.trim();
    if (loc != null && loc.isNotEmpty) return loc;
    return 'Centre';
  }

  factory PlaceBranchOption.fromJson(Map<String, dynamic> json) {
    return PlaceBranchOption(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      location: json['location'] as String?,
      addressLine1: json['address_line1'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      country: json['country'] as String?,
      postalCode: json['postal_code'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      geofenceRadiusM: json['geofence_radius_m'] as int?,
    );
  }
}

class PlaceParticipantSiteOption {
  const PlaceParticipantSiteOption({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.name,
    this.addressLine1,
    this.city,
    this.state,
    this.country,
    this.postalCode,
    this.latitude,
    this.longitude,
    this.geofenceRadiusM,
    this.isPrimary = false,
  });

  final String id;
  final String clientId;
  final String clientName;
  final String name;
  final String? addressLine1;
  final String? city;
  final String? state;
  final String? country;
  final String? postalCode;
  final double? latitude;
  final double? longitude;
  final int? geofenceRadiusM;
  final bool isPrimary;

  String get displayAddress {
    final parts = <String>[
      if (addressLine1 != null && addressLine1!.trim().isNotEmpty)
        addressLine1!.trim(),
      if (city != null && city!.trim().isNotEmpty) city!.trim(),
      if (state != null && state!.trim().isNotEmpty) state!.trim(),
      if (postalCode != null && postalCode!.trim().isNotEmpty)
        postalCode!.trim(),
      if (country != null && country!.trim().isNotEmpty) country!.trim(),
    ];
    return parts.join(', ');
  }

  factory PlaceParticipantSiteOption.fromJson(Map<String, dynamic> json) {
    return PlaceParticipantSiteOption(
      id: json['id'].toString(),
      clientId: json['client_id'].toString(),
      clientName: json['client_name'] as String? ?? '',
      name: json['name'] as String? ?? '',
      addressLine1: json['address_line1'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      country: json['country'] as String?,
      postalCode: json['postal_code'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      geofenceRadiusM: json['geofence_radius_m'] as int?,
      isPrimary: json['is_primary'] as bool? ?? false,
    );
  }
}

class PlaceOptionsOut {
  const PlaceOptionsOut({
    this.branches = const [],
    this.participantSites = const [],
  });

  final List<PlaceBranchOption> branches;
  final List<PlaceParticipantSiteOption> participantSites;

  factory PlaceOptionsOut.fromJson(Map<String, dynamic> json) {
    return PlaceOptionsOut(
      branches: (json['branches'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => PlaceBranchOption.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
      participantSites: (json['participant_sites'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (e) => PlaceParticipantSiteOption.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList(growable: false),
    );
  }
}

class SupportSegmentOut {
  const SupportSegmentOut({
    required this.id,
    required this.shiftId,
    required this.visitId,
    required this.shiftParticipantId,
    required this.anchorSupportItemCode,
    required this.anchorSupportItemName,
    required this.kind,
    required this.startAt,
    required this.endAt,
    required this.sortOrder,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.groupSize,
    this.notes,
  });

  final String id;
  final String shiftId;
  final String visitId;
  final String shiftParticipantId;
  final String anchorSupportItemCode;
  final String anchorSupportItemName;
  final String kind;
  final DateTime startAt;
  final DateTime endAt;
  final int? groupSize;
  final String? notes;
  final int sortOrder;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory SupportSegmentOut.fromJson(Map<String, dynamic> json) {
    return SupportSegmentOut(
      id: json['id'].toString(),
      shiftId: json['shift_id'].toString(),
      visitId: json['visit_id'].toString(),
      shiftParticipantId: json['shift_participant_id'].toString(),
      anchorSupportItemCode:
          json['anchor_support_item_code'] as String? ?? '',
      anchorSupportItemName:
          json['anchor_support_item_name'] as String? ?? '',
      kind: json['kind'] as String? ?? 'direct',
      startAt: DateTime.parse(json['start_at'] as String),
      endAt: DateTime.parse(json['end_at'] as String),
      groupSize: json['group_size'] as int?,
      notes: json['notes'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      status: json['status'] as String? ?? 'planned',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class SupportSegmentIn {
  const SupportSegmentIn({
    required this.shiftParticipantId,
    required this.anchorSupportItemCode,
    required this.startAt,
    required this.endAt,
    this.kind = 'direct',
    this.groupSize,
    this.notes,
    this.sortOrder = 0,
  });

  final String shiftParticipantId;
  final String anchorSupportItemCode;
  final String kind;
  final DateTime startAt;
  final DateTime endAt;
  final int? groupSize;
  final String? notes;
  final int sortOrder;

  Map<String, dynamic> toJson() => {
    'shift_participant_id': shiftParticipantId,
    'anchor_support_item_code': anchorSupportItemCode,
    'kind': kind,
    'start_at': startAt.toUtc().toIso8601String(),
    'end_at': endAt.toUtc().toIso8601String(),
    if (groupSize != null) 'group_size': groupSize,
    if (notes != null) 'notes': notes,
    'sort_order': sortOrder,
  };
}

class ShiftLiteOut {
  const ShiftLiteOut({
    required this.id,
    required this.jobId,
    required this.scheduledStart,
    required this.scheduledEnd,
    this.contractorIds = const [],
  });

  final String id;
  final String jobId;
  final List<String> contractorIds;
  final DateTime scheduledStart;
  final DateTime scheduledEnd;

  factory ShiftLiteOut.fromJson(Map<String, dynamic> json) {
    return ShiftLiteOut(
      id: json['id'].toString(),
      jobId: json['job_id'].toString(),
      contractorIds: (json['contractor_ids'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      scheduledStart: DateTime.parse(json['scheduled_start'] as String),
      scheduledEnd: DateTime.parse(json['scheduled_end'] as String),
    );
  }
}

class VisitLiteOut {
  const VisitLiteOut({
    required this.id,
    required this.contractorId,
    required this.scheduledStart,
    required this.scheduledEnd,
    this.clientId,
  });

  final String id;
  final String? clientId;
  final String contractorId;
  final DateTime scheduledStart;
  final DateTime scheduledEnd;

  factory VisitLiteOut.fromJson(Map<String, dynamic> json) {
    return VisitLiteOut(
      id: json['id'].toString(),
      clientId: json['client_id']?.toString(),
      contractorId: json['contractor_id'].toString(),
      scheduledStart: DateTime.parse(json['scheduled_start'] as String),
      scheduledEnd: DateTime.parse(json['scheduled_end'] as String),
    );
  }
}

class ClientConflictOut {
  const ClientConflictOut({
    required this.id,
    required this.kind,
    required this.scheduledStart,
    required this.scheduledEnd,
    this.clientId,
    this.contractorId,
    this.jobId,
  });

  final String id;
  final String kind; // visit | shift
  final String? clientId;
  final String? contractorId;
  final String? jobId;
  final DateTime scheduledStart;
  final DateTime scheduledEnd;

  factory ClientConflictOut.fromJson(Map<String, dynamic> json) {
    return ClientConflictOut(
      id: json['id'].toString(),
      kind: json['kind'] as String? ?? 'visit',
      clientId: json['client_id']?.toString(),
      contractorId: json['contractor_id']?.toString(),
      jobId: json['job_id']?.toString(),
      scheduledStart: DateTime.parse(json['scheduled_start'] as String),
      scheduledEnd: DateTime.parse(json['scheduled_end'] as String),
    );
  }
}

/// Capped assign-context aggregate (`GET /v1/roster/assign-context`).
class AssignContextOut {
  const AssignContextOut({
    this.shiftsLite = const [],
    this.visitsLite = const [],
    this.overlay = const RosterOverlayOut(),
    this.clientConflicts = const [],
  });

  final List<ShiftLiteOut> shiftsLite;
  final List<VisitLiteOut> visitsLite;
  final RosterOverlayOut overlay;
  final List<ClientConflictOut> clientConflicts;

  factory AssignContextOut.fromJson(Map<String, dynamic> json) {
    final overlayRaw = json['overlay'];
    return AssignContextOut(
      shiftsLite: (json['shifts_lite'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => ShiftLiteOut.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
      visitsLite: (json['visits_lite'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => VisitLiteOut.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
      overlay:
          overlayRaw is Map
              ? RosterOverlayOut.fromJson(Map<String, dynamic>.from(overlayRaw))
              : const RosterOverlayOut(),
      clientConflicts: (json['client_conflicts'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => ClientConflictOut.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
    );
  }
}
