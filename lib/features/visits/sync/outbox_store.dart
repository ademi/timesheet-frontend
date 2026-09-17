import 'package:get_storage/get_storage.dart';

import 'outbox_models.dart';

class OutboxStore {
  OutboxStore(this._box);
  final GetStorage _box;
  static const _key = 'visit_clock_outbox_v1';

  List<ClockOutboxItem> pending() {
    final raw = _box.read<List>(_key) ?? const [];
    return raw
        .map((e) => ClockOutboxItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(growable: false);
  }

  Future<void> append(ClockOutboxItem item) async {
    final next = [...pending(), item];
    await _box.write(_key, next.map((e) => e.toJson()).toList());
  }

  Future<void> ack(String clientEventId) async {
    final next = pending().where((e) => e.clientEventId != clientEventId).toList();
    await _box.write(_key, next.map((e) => e.toJson()).toList());
  }

  Future<void> markAttempt(String clientEventId, String error) async {
    final next = pending().map((e) {
      if (e.clientEventId != clientEventId) return e;
      return ClockOutboxItem(
        clientEventId: e.clientEventId,
        visitId: e.visitId,
        kind: e.kind,
        tapTimeIso: e.tapTimeIso,
        locationStatus: e.locationStatus,
        locationFailReason: e.locationFailReason,
        lat: e.lat,
        lng: e.lng,
        accuracyM: e.accuracyM,
        deviceOffline: e.deviceOffline,
        attempts: e.attempts + 1,
        lastError: error,
      );
    }).toList();
    await _box.write(_key, next.map((e) => e.toJson()).toList());
  }

  void clearDestructive({required bool confirmDiscard}) {
    if (!confirmDiscard && pending().isNotEmpty) {
      throw StateError('outbox_not_empty');
    }
    _box.remove(_key);
  }
}
