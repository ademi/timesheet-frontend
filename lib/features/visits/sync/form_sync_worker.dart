import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

import '../../../core/errors/app_failure.dart';
import '../data/models/visit_models.dart';
import '../data/repositories/visits_repository.dart';
import 'form_draft_models.dart';
import 'form_draft_store.dart';

/// Flushes queued visit form submits when online (B2).
class FormSyncWorker with WidgetsBindingObserver {
  FormSyncWorker({
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

  final FormDraftStore store;
  final VisitsRepository repository;
  final void Function(FormDraftItem item)? onAcked;
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
    unawaited(Future.microtask(flush));
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
      results.isEmpty || results.every((r) => r == ConnectivityResult.none);

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
          final items = [
            for (final e in store.pendingFlush())
              if (!attempted.contains(e.draftKey)) e,
          ]..sort((a, b) => a.updatedAtIso.compareTo(b.updatedAtIso));
          if (items.isEmpty) break;
          final next = items.first;
          attempted.add(next.draftKey);
          if (pushedInPass) {
            await Future<void>.delayed(_backoffForAttempt(next.attempts));
          }
          final stillThere =
              store.pendingFlush().any((e) => e.draftKey == next.draftKey);
          if (!stillThere) continue;
          final current = store
              .pendingFlush()
              .firstWhere((e) => e.draftKey == next.draftKey);
          await _pushOne(current);
          pushedInPass = true;
        }
      } while (_flushAgain);
    } finally {
      _flushing = false;
      onChanged?.call();
    }
  }

  Future<bool> _pushOne(FormDraftItem item) async {
    final eventId = item.clientEventId;
    if (eventId == null || eventId.isEmpty) return false;
    try {
      await repository.submitForm(
        visitId: item.visitId,
        body: VisitFormSubmitRequest(
          formTemplateId: item.formTemplateId,
          payloadJson: item.payloadJson,
          clientEventId: eventId,
        ),
      );
      await store.ack(item.draftKey);
      onAcked?.call(item);
      onChanged?.call();
      return true;
    } on AppFailure catch (e) {
      if (_isTerminal(e)) {
        await store.markTerminalFailure(item.draftKey, e.message);
      } else {
        await store.markAttempt(item.draftKey, e.message);
      }
      onChanged?.call();
      return false;
    } catch (e) {
      await store.markAttempt(item.draftKey, e.toString());
      onChanged?.call();
      return false;
    }
  }

  static bool _isTerminal(AppFailure e) {
    final code = e.statusCode;
    if (code == null) return false;
    // 4xx except 408/429 are terminal (conflict / validation).
    if (code == 408 || code == 429) return false;
    return code >= 400 && code < 500;
  }
}
