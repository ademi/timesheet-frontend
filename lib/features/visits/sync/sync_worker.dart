import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

import '../../../core/errors/app_failure.dart';
import '../data/models/visit_models.dart';
import '../data/repositories/visits_repository.dart';
import 'outbox_models.dart';
import 'outbox_store.dart';

/// D4: sort by tap time; defer complete while a check-in for the same visit
/// is still pending.
List<ClockOutboxItem> orderedForFlush(List<ClockOutboxItem> pending) {
  final sorted = [...pending]
    ..sort((a, b) => a.tapTimeIso.compareTo(b.tapTimeIso));
  final out = <ClockOutboxItem>[];
  final checkInStillPending = sorted
      .where((e) => e.kind == ClockOutboxKind.checkIn)
      .map((e) => e.visitId)
      .toSet();
  for (final item in sorted) {
    if (item.kind == ClockOutboxKind.complete &&
        checkInStillPending.contains(item.visitId)) {
      continue;
    }
    out.add(item);
  }
  return out;
}

VisitGpsBody gpsBodyFromOutbox(ClockOutboxItem item) => VisitGpsBody(
      lat: item.lat,
      lng: item.lng,
      accuracyM: item.accuracyM,
      clientEventId: item.clientEventId,
      tapTime: DateTime.tryParse(item.tapTimeIso),
      locationStatus: item.locationStatus,
      locationFailReason: item.locationFailReason,
      deviceOffline: item.deviceOffline,
    );

/// Pushes pending clock events when online (D5) with single-flight + backoff (D8).
class SyncWorker with WidgetsBindingObserver {
  SyncWorker({
    required this.store,
    required this.repository,
    Stream<List<ConnectivityResult>>? connectivityStream,
    this.onAcked,
    this.onChanged,
    Duration Function(int attempts)? backoffForAttempt,
    bool observeLifecycle = true,
  })  : _connectivityStream =
            connectivityStream ?? Connectivity().onConnectivityChanged,
        _backoffForAttempt = backoffForAttempt ?? defaultBackoffForAttempt,
        _observeLifecycle = observeLifecycle;

  final OutboxStore store;
  final VisitsRepository repository;
  final void Function(ClockOutboxItem item)? onAcked;
  final void Function()? onChanged;
  final Stream<List<ConnectivityResult>> _connectivityStream;
  final Duration Function(int attempts) _backoffForAttempt;
  final bool _observeLifecycle;

  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _started = false;
  bool _flushing = false;
  bool _flushAgain = false;
  List<ConnectivityResult> _last = const [ConnectivityResult.none];

  static Duration defaultBackoffForAttempt(int attempts) {
    final ms = (200 * (1 << attempts.clamp(0, 4))).clamp(200, 5000);
    return Duration(milliseconds: ms);
  }

  void start() {
    if (_started) return;
    _started = true;
    if (_observeLifecycle) {
      WidgetsBinding.instance.addObserver(this);
    }
    _sub = _connectivityStream.listen(_onConnectivity);
  }

  void dispose() {
    if (!_started) return;
    _started = false;
    if (_observeLifecycle) {
      WidgetsBinding.instance.removeObserver(this);
    }
    _sub?.cancel();
    _sub = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(flush());
    }
  }

  void _onConnectivity(List<ConnectivityResult> next) {
    final wasOffline = _isOffline(_last);
    final nowOnline = !_isOffline(next);
    _last = next;
    if (wasOffline && nowOnline) {
      unawaited(flush());
    }
  }

  static bool _isOffline(List<ConnectivityResult> results) =>
      results.isEmpty ||
      results.every((r) => r == ConnectivityResult.none);

  /// Single-flight flush: overlapping calls coalesce into one follow-up pass.
  Future<void> flush() async {
    if (_flushing) {
      _flushAgain = true;
      return;
    }
    _flushing = true;
    try {
      do {
        _flushAgain = false;
        final items = orderedForFlush(store.pending());
        for (var i = 0; i < items.length; i++) {
          if (i > 0) {
            await Future<void>.delayed(
              _backoffForAttempt(items[i].attempts),
            );
          }
          // Re-read pending — prior ack may have changed ordering eligibility.
          final stillThere = store
              .pending()
              .any((e) => e.clientEventId == items[i].clientEventId);
          if (!stillThere) continue;
          final current = store
              .pending()
              .firstWhere((e) => e.clientEventId == items[i].clientEventId);
          await _pushOne(current);
        }
      } while (_flushAgain);
    } finally {
      _flushing = false;
      onChanged?.call();
    }
  }

  Future<bool> _pushOne(ClockOutboxItem item) async {
    try {
      final body = gpsBodyFromOutbox(item);
      if (item.kind == ClockOutboxKind.checkIn) {
        await repository.checkIn(
          id: item.visitId,
          body: body,
          idempotencyKey: item.clientEventId,
        );
      } else {
        await repository.complete(
          id: item.visitId,
          body: body,
          idempotencyKey: item.clientEventId,
        );
      }
      await store.ack(item.clientEventId);
      onAcked?.call(item);
      onChanged?.call();
      return true;
    } on AppFailure catch (e) {
      await store.markAttempt(item.clientEventId, e.message);
      onChanged?.call();
      return false;
    } catch (e) {
      await store.markAttempt(item.clientEventId, e.toString());
      onChanged?.call();
      return false;
    }
  }
}
