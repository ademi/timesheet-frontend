/// SIL house + funded roster-of-care models (B3).

class SilHouseOut {
  const SilHouseOut({
    required this.id,
    required this.tenantId,
    required this.name,
    this.addressLine1,
    this.city,
    this.postalCode,
    this.isActive = true,
    this.bedCapacity,
    this.fixedWeeklyCost,
  });

  final String id;
  final String tenantId;
  final String name;
  final String? addressLine1;
  final String? city;
  final String? postalCode;
  final bool isActive;
  final int? bedCapacity;
  final double? fixedWeeklyCost;

  factory SilHouseOut.fromJson(Map<String, dynamic> json) => SilHouseOut(
    id: json['id'].toString(),
    tenantId: json['tenant_id'].toString(),
    name: json['name'] as String,
    addressLine1: json['address_line1'] as String?,
    city: json['city'] as String?,
    postalCode: json['postal_code'] as String?,
    isActive: json['is_active'] as bool? ?? true,
    bedCapacity: json['bed_capacity'] as int?,
    fixedWeeklyCost: (json['fixed_weekly_cost'] as num?)?.toDouble(),
  );
}

class SilHouseMemberOut {
  const SilHouseMemberOut({
    required this.id,
    required this.houseId,
    required this.clientId,
    this.clientName,
    required this.occupancyStatus,
    this.bedLabel,
  });

  final String id;
  final String houseId;
  final String clientId;
  final String? clientName;
  final String occupancyStatus;
  final String? bedLabel;

  factory SilHouseMemberOut.fromJson(Map<String, dynamic> json) =>
      SilHouseMemberOut(
        id: json['id'].toString(),
        houseId: json['house_id'].toString(),
        clientId: json['client_id'].toString(),
        clientName: json['client_name'] as String?,
        occupancyStatus: json['occupancy_status'] as String? ?? 'present',
        bedLabel: json['bed_label'] as String?,
      );

  bool get isPresent => occupancyStatus == 'present';
}

class SilRocBlockOut {
  const SilRocBlockOut({
    required this.id,
    required this.houseId,
    required this.band,
    required this.fundedWorkerCount,
    required this.fundedParticipantCount,
  });

  final String id;
  final String houseId;
  final String band;
  final int fundedWorkerCount;
  final int fundedParticipantCount;

  factory SilRocBlockOut.fromJson(Map<String, dynamic> json) => SilRocBlockOut(
    id: json['id'].toString(),
    houseId: json['house_id'].toString(),
    band: json['band'] as String,
    fundedWorkerCount: json['funded_worker_count'] as int? ?? 1,
    fundedParticipantCount: json['funded_participant_count'] as int? ?? 1,
  );

  String get ratioLabel =>
      '$fundedWorkerCount:$fundedParticipantCount';
}

class SilHouseBundleOut {
  const SilHouseBundleOut({
    required this.house,
    required this.members,
    required this.rocBlocks,
    required this.presentOccupancy,
  });

  final SilHouseOut house;
  final List<SilHouseMemberOut> members;
  final List<SilRocBlockOut> rocBlocks;
  final int presentOccupancy;

  factory SilHouseBundleOut.fromJson(Map<String, dynamic> json) =>
      SilHouseBundleOut(
        house: SilHouseOut.fromJson(
          Map<String, dynamic>.from(json['house'] as Map),
        ),
        members: (json['members'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (e) => SilHouseMemberOut.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList(growable: false),
        rocBlocks: (json['roc_blocks'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => SilRocBlockOut.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false),
        presentOccupancy: json['present_occupancy'] as int? ?? 0,
      );
}

class SilCompatRuleOut {
  const SilCompatRuleOut({
    required this.id,
    required this.houseId,
    this.contractorId,
    this.againstClientId,
    required this.severity,
    required this.reason,
    this.isActive = true,
  });

  final String id;
  final String houseId;
  final String? contractorId;
  final String? againstClientId;
  final String severity;
  final String reason;
  final bool isActive;

  factory SilCompatRuleOut.fromJson(Map<String, dynamic> json) =>
      SilCompatRuleOut(
        id: json['id'].toString(),
        houseId: json['house_id'].toString(),
        contractorId: json['contractor_id']?.toString(),
        againstClientId: json['against_client_id']?.toString(),
        severity: json['severity'] as String? ?? 'soft_warn',
        reason: json['reason'] as String? ?? '',
        isActive: json['is_active'] as bool? ?? true,
      );

  bool get isHard => severity == 'hard_block';
}

class SilCompatRuleCreateRequest {
  const SilCompatRuleCreateRequest({
    this.contractorId,
    this.againstClientId,
    this.severity = 'soft_warn',
    required this.reason,
  });

  final String? contractorId;
  final String? againstClientId;
  final String severity;
  final String reason;

  Map<String, dynamic> toJson() => {
    if (contractorId != null) 'contractor_id': contractorId,
    if (againstClientId != null) 'against_client_id': againstClientId,
    'severity': severity,
    'reason': reason,
  };
}

class SilHouseCreateRequest {
  const SilHouseCreateRequest({
    required this.name,
    this.addressLine1,
    this.city,
    this.postalCode,
    this.bedCapacity,
    this.fixedWeeklyCost,
  });

  final String name;
  final String? addressLine1;
  final String? city;
  final String? postalCode;
  final int? bedCapacity;
  final double? fixedWeeklyCost;

  Map<String, dynamic> toJson() => {
    'name': name,
    if (addressLine1 != null) 'address_line1': addressLine1,
    if (city != null) 'city': city,
    if (postalCode != null) 'postal_code': postalCode,
    if (bedCapacity != null) 'bed_capacity': bedCapacity,
    if (fixedWeeklyCost != null) 'fixed_weekly_cost': fixedWeeklyCost,
  };
}

class SilHousePatchRequest {
  const SilHousePatchRequest({
    this.bedCapacity,
    this.fixedWeeklyCost,
    this.clearFixedWeeklyCost = false,
  });

  final int? bedCapacity;
  final double? fixedWeeklyCost;
  final bool clearFixedWeeklyCost;

  Map<String, dynamic> toJson() => {
    if (bedCapacity != null) 'bed_capacity': bedCapacity,
    if (fixedWeeklyCost != null) 'fixed_weekly_cost': fixedWeeklyCost,
    if (clearFixedWeeklyCost) 'clear_fixed_weekly_cost': true,
  };
}

class SilVacancyOverlayOut {
  const SilVacancyOverlayOut({
    required this.houseId,
    required this.presentOccupancy,
    required this.vacantCount,
    required this.warningCodes,
    required this.publishedShiftCount,
    this.bedCapacity,
    this.fixedWeeklyCost,
    this.costPerPresentBed,
  });

  final String houseId;
  final int? bedCapacity;
  final int presentOccupancy;
  final int vacantCount;
  final double? fixedWeeklyCost;
  final double? costPerPresentBed;
  final List<String> warningCodes;
  final int publishedShiftCount;

  factory SilVacancyOverlayOut.fromJson(Map<String, dynamic> json) =>
      SilVacancyOverlayOut(
        houseId: json['house_id'].toString(),
        bedCapacity: json['bed_capacity'] as int?,
        presentOccupancy: json['present_occupancy'] as int? ?? 0,
        vacantCount: json['vacant_count'] as int? ?? 0,
        fixedWeeklyCost: (json['fixed_weekly_cost'] as num?)?.toDouble(),
        costPerPresentBed: (json['cost_per_present_bed'] as num?)?.toDouble(),
        warningCodes: (json['warning_codes'] as List? ?? const [])
            .map((e) => e.toString())
            .toList(growable: false),
        publishedShiftCount: json['published_shift_count'] as int? ?? 0,
      );
}

class SilFillVacancyRequest {
  const SilFillVacancyRequest({
    required this.scheduledStart,
    required this.scheduledEnd,
    this.jobId,
  });

  final DateTime scheduledStart;
  final DateTime scheduledEnd;
  final String? jobId;

  Map<String, dynamic> toJson() => {
    'scheduled_start': scheduledStart.toUtc().toIso8601String(),
    'scheduled_end': scheduledEnd.toUtc().toIso8601String(),
    if (jobId != null) 'job_id': jobId,
  };
}

class SilFillVacancyOut {
  const SilFillVacancyOut({
    required this.shiftId,
    required this.jobId,
    required this.status,
  });

  final String shiftId;
  final String jobId;
  final String status;

  factory SilFillVacancyOut.fromJson(Map<String, dynamic> json) =>
      SilFillVacancyOut(
        shiftId: json['shift_id'].toString(),
        jobId: json['job_id'].toString(),
        status: json['status'] as String? ?? 'draft',
      );
}

class SilHouseMemberUpsertRequest {
  const SilHouseMemberUpsertRequest({
    required this.clientId,
    this.occupancyStatus = 'present',
    this.bedLabel,
  });

  final String clientId;
  final String occupancyStatus;
  final String? bedLabel;

  Map<String, dynamic> toJson() => {
    'client_id': clientId,
    'occupancy_status': occupancyStatus,
    if (bedLabel != null) 'bed_label': bedLabel,
  };
}

class SilRocBlockUpsertRequest {
  const SilRocBlockUpsertRequest({
    required this.band,
    required this.fundedWorkerCount,
    required this.fundedParticipantCount,
  });

  final String band;
  final int fundedWorkerCount;
  final int fundedParticipantCount;

  Map<String, dynamic> toJson() => {
    'band': band,
    'funded_worker_count': fundedWorkerCount,
    'funded_participant_count': fundedParticipantCount,
  };
}

/// Human labels for soft ROC publish warnings.
String silWarningLabel(String code) {
  switch (code) {
    case 'roc_staffing_richer':
      return 'Staffing richer than funded ROC';
    case 'roc_staffing_thinner':
      return 'Staffing thinner than funded ROC';
    case 'roc_participant_drift':
      return 'Participant count differs from funded / present occupancy';
    case 'roc_occupancy_absent_on_shift':
      return 'Shift includes a vacant/hospital housemate';
    case 'roc_block_missing':
      return 'No funded ROC block for this time of day';
    case 'worker_count_slots_mismatch':
      return 'Workers planned ≠ open slots';
    case 'vacancy_bed_underfilled':
      return 'Beds underfilled vs capacity';
    case 'vacancy_member_absent':
      return 'Member vacant / hospital / absent';
    case 'creep_staffing_above_roc':
      return 'Staffed above funded ROC';
    case 'creep_unfunded_shift':
      return 'Published shift without ROC stamp';
    case 'cost_occupancy_gap':
      return 'Fixed cost spread over underfilled beds';
    case 'assign_soft:mealtime_assist':
      return 'Worker lacks mealtime assistance competency';
    case 'assign_soft:bsp_support':
      return 'Worker lacks BSP support competency';
    case 'assign_soft:housemate_compat':
      return 'Housemate compatibility preference warning';
    default:
      if (code.startsWith('assign_soft:')) {
        return 'Assign soft warning: ${code.substring('assign_soft:'.length)}';
      }
      return code;
  }
}
