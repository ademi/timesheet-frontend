/// Contractor schedule DTOs (design §6.9 / wiring guide §10).
class TimetableVisitOut {
  const TimetableVisitOut({
    required this.id,
    required this.tenantId,
    required this.jobId,
    required this.scheduledStart,
    required this.scheduledEnd,
    required this.status,
    this.tenantName,
  });

  final String id;
  final String tenantId;
  final String? tenantName;
  final String jobId;
  final DateTime scheduledStart;
  final DateTime scheduledEnd;
  final String status;

  factory TimetableVisitOut.fromJson(Map<String, dynamic> json) {
    return TimetableVisitOut(
      id: json['id'].toString(),
      tenantId: json['tenant_id'].toString(),
      tenantName: json['tenant_name'] as String?,
      jobId: json['job_id'].toString(),
      scheduledStart: DateTime.parse(json['scheduled_start'] as String),
      scheduledEnd: DateTime.parse(json['scheduled_end'] as String),
      status: json['status'] as String? ?? 'scheduled',
    );
  }
}

class AvailabilityRuleOut {
  const AvailabilityRuleOut({
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.id,
  });

  /// 0=Monday … 6=Sunday (API contract).
  final int dayOfWeek;
  final String startTime; // HH:MM:SS or HH:MM
  final String endTime;
  final String? id;

  factory AvailabilityRuleOut.fromJson(Map<String, dynamic> json) {
    return AvailabilityRuleOut(
      id: json['id']?.toString(),
      dayOfWeek: json['day_of_week'] as int? ?? 0,
      startTime: _normalizeTime(json['start_time']?.toString() ?? '09:00:00'),
      endTime: _normalizeTime(json['end_time']?.toString() ?? '17:00:00'),
    );
  }

  Map<String, dynamic> toRuleJson() => {
        'day_of_week': dayOfWeek,
        'start_time': _ensureSeconds(startTime),
        'end_time': _ensureSeconds(endTime),
      };

  static String _normalizeTime(String raw) {
    final parts = raw.split(':');
    if (parts.length >= 2) {
      return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
    }
    return raw;
  }

  static String _ensureSeconds(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length == 2) return '$hhmm:00';
    return hhmm;
  }
}

class LeaveOut {
  const LeaveOut({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.leaveType,
    this.notes,
  });

  final String id;
  final String startDate; // YYYY-MM-DD
  final String endDate;
  final String leaveType;
  final String? notes;

  factory LeaveOut.fromJson(Map<String, dynamic> json) {
    return LeaveOut(
      id: json['id'].toString(),
      startDate: _dateOnly(json['start_date']),
      endDate: _dateOnly(json['end_date']),
      leaveType: json['leave_type'] as String? ?? 'annual',
      notes: json['notes'] as String?,
    );
  }

  static String _dateOnly(Object? raw) {
    final s = raw?.toString() ?? '';
    if (s.length >= 10) return s.substring(0, 10);
    return s;
  }
}

class LeaveCreateRequest {
  const LeaveCreateRequest({
    required this.startDate,
    required this.endDate,
    required this.leaveType,
    this.notes,
  });

  final String startDate;
  final String endDate;
  final String leaveType;
  final String? notes;

  Map<String, dynamic> toJson() => {
        'start_date': startDate,
        'end_date': endDate,
        'leave_type': leaveType,
        if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
      };
}

class TimetableOut {
  const TimetableOut({
    required this.from,
    required this.to,
    this.visits = const [],
    this.availability = const [],
    this.leave = const [],
  });

  final DateTime from;
  final DateTime to;
  final List<TimetableVisitOut> visits;
  final List<AvailabilityRuleOut> availability;
  final List<LeaveOut> leave;

  factory TimetableOut.fromJson(Map<String, dynamic> json) {
    List<T> mapList<T>(Object? raw, T Function(Map<String, dynamic>) map) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => map(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    }

    return TimetableOut(
      from: DateTime.parse(json['from'] as String),
      to: DateTime.parse(json['to'] as String),
      visits: mapList(json['visits'], TimetableVisitOut.fromJson),
      availability: mapList(json['availability'], AvailabilityRuleOut.fromJson),
      leave: mapList(json['leave'], LeaveOut.fromJson),
    );
  }
}

const dayOfWeekLabels = <String>[
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const leaveTypeOptions = <String>[
  'annual',
  'sick',
  'unpaid',
  'other',
];
