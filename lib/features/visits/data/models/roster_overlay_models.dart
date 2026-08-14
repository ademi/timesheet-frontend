/// Staff roster overlay DTOs (`GET /v1/workforce/roster-overlay`).

class LeaveIntervalOut {
  const LeaveIntervalOut({
    required this.startDate,
    required this.endDate,
    required this.leaveType,
  });

  final DateTime startDate;
  final DateTime endDate;
  final String leaveType;

  factory LeaveIntervalOut.fromJson(Map<String, dynamic> json) {
    return LeaveIntervalOut(
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      leaveType: json['leave_type'] as String? ?? 'leave',
    );
  }
}

class AvailabilityRuleOut {
  const AvailabilityRuleOut({
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
  });

  /// 0 = Monday .. 6 = Sunday (matches backend).
  final int dayOfWeek;
  final String startTime;
  final String endTime;

  factory AvailabilityRuleOut.fromJson(Map<String, dynamic> json) {
    return AvailabilityRuleOut(
      dayOfWeek: json['day_of_week'] as int? ?? 0,
      startTime: json['start_time'] as String? ?? '00:00:00',
      endTime: json['end_time'] as String? ?? '23:59:59',
    );
  }
}

class ContractorRosterOverlay {
  const ContractorRosterOverlay({
    required this.contractorId,
    required this.displayName,
    this.leave = const [],
    this.availability = const [],
  });

  final String contractorId;
  final String displayName;
  final List<LeaveIntervalOut> leave;
  final List<AvailabilityRuleOut> availability;

  factory ContractorRosterOverlay.fromJson(Map<String, dynamic> json) {
    return ContractorRosterOverlay(
      contractorId: json['contractor_id'].toString(),
      displayName: json['display_name'] as String? ?? 'Worker',
      leave: (json['leave'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => LeaveIntervalOut.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
      availability: (json['availability'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => AvailabilityRuleOut.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
    );
  }
}

class RosterOverlayOut {
  const RosterOverlayOut({
    this.contractors = const [],
    this.truncated = false,
  });

  final List<ContractorRosterOverlay> contractors;
  final bool truncated;

  factory RosterOverlayOut.fromJson(Map<String, dynamic> json) {
    return RosterOverlayOut(
      contractors: (json['contractors'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => ContractorRosterOverlay.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
      truncated: json['truncated'] as bool? ?? false,
    );
  }
}
