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
    this.isConflict = false,
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
  final bool isConflict;

  /// API kind for sync-conflict create (`check_in` | `complete`).
  String get apiKind =>
      kind == ClockOutboxKind.checkIn ? 'check_in' : 'complete';

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
        'is_conflict': isConflict,
      };

  /// Frozen payload posted to sync-conflicts (API kind naming).
  Map<String, dynamic> toConflictPayloadJson() => {
        'client_event_id': clientEventId,
        'visit_id': visitId,
        'kind': apiKind,
        'tap_time': tapTimeIso,
        'location_status': locationStatus,
        'location_fail_reason': locationFailReason,
        'lat': lat,
        'lng': lng,
        'accuracy_m': accuracyM,
        'device_offline': deviceOffline,
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
        isConflict: j['is_conflict'] as bool? ?? false,
      );

  ClockOutboxItem copyWith({
    int? attempts,
    String? lastError,
    bool clearLastError = false,
    bool? isConflict,
  }) =>
      ClockOutboxItem(
        clientEventId: clientEventId,
        visitId: visitId,
        kind: kind,
        tapTimeIso: tapTimeIso,
        locationStatus: locationStatus,
        locationFailReason: locationFailReason,
        lat: lat,
        lng: lng,
        accuracyM: accuracyM,
        deviceOffline: deviceOffline,
        attempts: attempts ?? this.attempts,
        lastError: clearLastError ? null : (lastError ?? this.lastError),
        isConflict: isConflict ?? this.isConflict,
      );
}
