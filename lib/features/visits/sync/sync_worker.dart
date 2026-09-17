import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

import '../../../core/errors/app_failure.dart';
import '../data/models/visit_models.dart';
import '../data/repositories/visits_repository.dart';
import 'outbox_models.dart';
import 'outbox_store.dart';
import 'sync_error_classifier.dart';

/// D4: sort by tap time; defer complete while a check-in for the same visit
/// is still pending (non-conflict). Skip items already marked as terminal
/// conflicts — conflicted check-ins must not block completes forever.
List<ClockOutboxItem> orderedForFlush(List<ClockOutboxItem> pending) {
  final sorted = [...pending]
    ..sort((a, b) => a.tapTimeIso.compareTo(b.tapTimeIso));
  final out = <ClockOutboxItem>[];
  final checkInStillPending = sorted
      .where((e) => e.kind == ClockOutboxKind.checkIn && !e.isConflict)
      .map((e) => e.visitId)
      .toSet();
  for (final item in sorted) {
    if (item.isConflict) continue;
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
    this.onConflict,
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
  final void Function(ClockOutboxItem item)? onConflict;
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
        final attempted = <String>{};
        var pushedInPass = false;
        while (true) {
          final items = orderedForFlush(store.pending())
              .where((e) => !attempted.contains(e.clientEventId))
              .toList();
          if (items.isEmpty) break;
          final next = items.first;
          attempted.add(next.clientEventId);
          if (pushedInPass) {
            await Future<void>.delayed(_backoffForAttempt(next.attempts));
          }
          final currentList = store.pending();
          final stillThere = currentList
              .any((e) => e.clientEventId == next.clientEventId);
          if (!stillThere) continue;
          final current = currentList
              .firstWhere((e) => e.clientEventId == next.clientEventId);
          if (current.isConflict) continue;
          await _pushOne(current);
          pushedInPass = true;
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
      await _handlePushFailure(item, e);
      return false;
    } catch (e) {
      await store.markAttempt(item.clientEventId, e.toString());
      onChanged?.call();
      return false;
    }
  }

  Future<void> _handlePushFailure(ClockOutboxItem item, AppFailure e) async {
    final failureClass = classifySyncFailure(
      statusCode: e.statusCode,
      detail: e.code,
    );
    if (failureClass == SyncFailureClass.terminal) {
      final detail =
          (e.code.isNotEmpty && e.code != 'unknown') ? e.code : e.message;
      try {
        await repository.reportSyncConflict(
          visitId: item.visitId,
          clientEventId: item.clientEventId,
          kind: item.apiKind,
          failureDetail: detail,
          payloadJson: item.toConflictPayloadJson(),
        );
        await store.markConflict(item.clientEventId, detail);
        onConflict?.call(item);
      } on AppFailure catch (reportErr) {
        // Could not report — keep retryable so we try conflict POST again.
        await store.markAttempt(
          item.clientEventId,
          reportErr.message,
        );
      } catch (reportErr) {
        await store.markAttempt(item.clientEventId, reportErr.toString());
      }
    } else {
      await store.markAttempt(item.clientEventId, e.message);
    }
    onChanged?.call();
  }
}
