enum ClockOutboxKind { checkIn, complete }

class ClockOutboxItem {
  const ClockOutboxItem({
    required this.clientEventId,
    required this.visitId,
    required this.kind,
    required this.tapTimeIso,
    required this.locationStatus,
    this.locationFailReason,
    this.lat,
    this.lng,
    this.accuracyM,
    this.deviceOffline = false,
    this.attempts = 0,
    this.lastError,
  });

  final String clientEventId;
  final String visitId;
  final ClockOutboxKind kind;
  final String tapTimeIso;
  final String locationStatus;
  final String? locationFailReason;
  final double? lat;
  final double? lng;
  final double? accuracyM;
  final bool deviceOffline;
  final int attempts;
  final String? lastError;

  Map<String, dynamic> toJson() => {
        'client_event_id': clientEventId,
        'visit_id': visitId,
        'kind': kind.name,
        'tap_time': tapTimeIso,
        'location_status': locationStatus,
        'location_fail_reason': locationFailReason,
        'lat': lat,
        'lng': lng,
        'accuracy_m': accuracyM,
        'device_offline': deviceOffline,
        'attempts': attempts,
        'last_error': lastError,
      };

  factory ClockOutboxItem.fromJson(Map<String, dynamic> j) => ClockOutboxItem(
        clientEventId: j['client_event_id'] as String,
        visitId: j['visit_id'] as String,
        kind: ClockOutboxKind.values.byName(j['kind'] as String),
        tapTimeIso: j['tap_time'] as String,
        locationStatus: j['location_status'] as String,
        locationFailReason: j['location_fail_reason'] as String?,
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        accuracyM: (j['accuracy_m'] as num?)?.toDouble(),
        deviceOffline: j['device_offline'] as bool? ?? false,
        attempts: j['attempts'] as int? ?? 0,
        lastError: j['last_error'] as String?,
      );
}
