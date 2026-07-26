/// Payroll rates + payment batch DTOs (design §6.10).
class RateBands {
  const RateBands({
    required this.base,
    this.evening,
    this.night,
    this.saturday,
    this.sunday,
    this.publicHoliday,
  });

  final double base;
  final double? evening;
  final double? night;
  final double? saturday;
  final double? sunday;
  final double? publicHoliday;

  factory RateBands.fromJson(Map<String, dynamic> json) {
    double? n(Object? v) => v == null ? null : (v as num).toDouble();
    return RateBands(
      base: (json['base'] as num?)?.toDouble() ??
          (json['hourly_rate'] as num?)?.toDouble() ??
          0,
      evening: n(json['evening']),
      night: n(json['night']),
      saturday: n(json['saturday']),
      sunday: n(json['sunday']),
      publicHoliday: n(json['public_holiday']),
    );
  }

  Map<String, dynamic> toJson() => {
        'base': base,
        if (evening != null) 'evening': evening,
        if (night != null) 'night': night,
        if (saturday != null) 'saturday': saturday,
        if (sunday != null) 'sunday': sunday,
        if (publicHoliday != null) 'public_holiday': publicHoliday,
      };
}

class EngagementRateOut {
  const EngagementRateOut({
    required this.id,
    required this.engagementId,
    required this.effectiveFrom,
    required this.currencyCode,
    required this.bands,
    this.effectiveTo,
    this.eveningStart,
    this.eveningEnd,
    this.nightStart,
    this.nightEnd,
    this.hourlyRate,
  });

  final String id;
  final String engagementId;
  final String effectiveFrom;
  final String? effectiveTo;
  final String currencyCode;
  final RateBands bands;
  final String? eveningStart;
  final String? eveningEnd;
  final String? nightStart;
  final String? nightEnd;
  /// Legacy single-rate field when bands absent.
  final double? hourlyRate;

  double get displayBase => bands.base > 0 ? bands.base : (hourlyRate ?? 0);

  factory EngagementRateOut.fromJson(Map<String, dynamic> json) {
    final bandsRaw = json['bands'];
    final RateBands bands;
    if (bandsRaw is Map) {
      bands = RateBands.fromJson(Map<String, dynamic>.from(bandsRaw));
    } else {
      bands = RateBands(
        base: (json['hourly_rate'] as num?)?.toDouble() ?? 0,
      );
    }
    return EngagementRateOut(
      id: json['id'].toString(),
      engagementId: (json['engagement_id'] ?? '').toString(),
      effectiveFrom: _dateOnly(json['effective_from']),
      effectiveTo: json['effective_to'] != null
          ? _dateOnly(json['effective_to'])
          : null,
      currencyCode: json['currency_code'] as String? ?? 'AUD',
      bands: bands,
      eveningStart: json['evening_start']?.toString(),
      eveningEnd: json['evening_end']?.toString(),
      nightStart: json['night_start']?.toString(),
      nightEnd: json['night_end']?.toString(),
      hourlyRate: (json['hourly_rate'] as num?)?.toDouble(),
    );
  }

  static String _dateOnly(Object? raw) {
    final s = raw?.toString() ?? '';
    return s.length >= 10 ? s.substring(0, 10) : s;
  }
}

class EngagementRateCreateRequest {
  const EngagementRateCreateRequest({
    required this.effectiveFrom,
    required this.bands,
    this.effectiveTo,
    this.currencyCode = 'AUD',
    this.eveningStart = '18:00:00',
    this.eveningEnd = '22:00:00',
    this.nightStart = '22:00:00',
    this.nightEnd = '06:00:00',
  });

  final String effectiveFrom;
  final String? effectiveTo;
  final String currencyCode;
  final RateBands bands;
  final String eveningStart;
  final String eveningEnd;
  final String nightStart;
  final String nightEnd;

  /// Sends bands + `hourly_rate` (= base) for wiring-guide compatibility.
  Map<String, dynamic> toJson() => {
        'effective_from': effectiveFrom,
        if (effectiveTo != null) 'effective_to': effectiveTo,
        'currency_code': currencyCode,
        'hourly_rate': bands.base,
        'bands': bands.toJson(),
        'evening_start': eveningStart,
        'evening_end': eveningEnd,
        'night_start': nightStart,
        'night_end': nightEnd,
      };
}

class PaymentBatchLineOut {
  const PaymentBatchLineOut({
    required this.visitId,
    required this.contractorId,
    required this.hours,
    required this.rate,
    required this.amount,
    this.bandBreakdown = const {},
  });

  final String visitId;
  final String contractorId;
  final double hours;
  final double rate;
  final double amount;
  final Map<String, dynamic> bandBreakdown;

  factory PaymentBatchLineOut.fromJson(Map<String, dynamic> json) {
    final breakdown = json['band_breakdown'];
    return PaymentBatchLineOut(
      visitId: json['visit_id'].toString(),
      contractorId: json['contractor_id'].toString(),
      hours: (json['hours'] as num?)?.toDouble() ?? 0,
      rate: (json['rate'] as num?)?.toDouble() ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      bandBreakdown: breakdown is Map
          ? Map<String, dynamic>.from(breakdown)
          : const {},
    );
  }
}

class PaymentBatchOut {
  const PaymentBatchOut({
    required this.id,
    required this.tenantId,
    required this.status,
    required this.currencyCode,
    required this.totalAmount,
    required this.createdAt,
    required this.updatedAt,
    this.periodLabel,
    this.postedAt,
    this.lines = const [],
  });

  final String id;
  final String tenantId;
  final String status; // draft | posted | void
  final String? periodLabel;
  final String currencyCode;
  final double totalAmount;
  final DateTime? postedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<PaymentBatchLineOut> lines;

  bool get isDraft => status == 'draft';
  bool get isPosted => status == 'posted';
  bool get isVoid => status == 'void' || status == 'voided';

  factory PaymentBatchOut.fromJson(Map<String, dynamic> json) {
    final linesRaw = json['lines'];
    return PaymentBatchOut(
      id: json['id'].toString(),
      tenantId: json['tenant_id'].toString(),
      status: json['status'] as String? ?? 'draft',
      periodLabel: json['period_label'] as String?,
      currencyCode: json['currency_code'] as String? ?? 'AUD',
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      postedAt: json['posted_at'] != null
          ? DateTime.tryParse(json['posted_at'].toString())
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      lines: linesRaw is List
          ? linesRaw
              .whereType<Map>()
              .map(
                (e) => PaymentBatchLineOut.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList(growable: false)
          : const [],
    );
  }
}

class PaymentBatchCreateRequest {
  const PaymentBatchCreateRequest({
    required this.visitIds,
    this.periodLabel,
    this.currencyCode = 'AUD',
  });

  final List<String> visitIds;
  final String? periodLabel;
  final String currencyCode;

  Map<String, dynamic> toJson() => {
        'visit_ids': visitIds,
        if (periodLabel != null && periodLabel!.isNotEmpty)
          'period_label': periodLabel,
        'currency_code': currencyCode,
      };
}

class TenantSettingsOut {
  const TenantSettingsOut({
    required this.id,
    this.name,
    this.timezone,
    this.publicHolidayJurisdiction,
  });

  final String id;
  final String? name;
  final String? timezone;
  final String? publicHolidayJurisdiction;

  factory TenantSettingsOut.fromJson(Map<String, dynamic> json) {
    return TenantSettingsOut(
      id: json['id'].toString(),
      name: json['name'] as String? ?? json['display_name'] as String?,
      timezone: json['timezone'] as String?,
      publicHolidayJurisdiction:
          json['public_holiday_jurisdiction'] as String?,
    );
  }
}
