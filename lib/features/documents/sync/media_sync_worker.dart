import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

import '../../../app/data/models/document/document_models.dart';
import '../../../core/errors/app_failure.dart';
import '../data/document_pipeline.dart';
import 'media_blob_store.dart';
import 'media_outbox_models.dart';
import 'media_outbox_store.dart';

/// Uploads pending media when online (A18) — single-flight + backoff like clock SyncWorker.
class MediaSyncWorker with WidgetsBindingObserver {
  MediaSyncWorker({
    required this.store,
    required this.blobs,
    required this.pipeline,
    Stream<List<ConnectivityResult>>? connectivityStream,
    this.onAcked,
    this.onChanged,
    Duration Function(int attempts)? backoffForAttempt,
    bool observeLifecycle = true,
  })  : _connectivityStream =
            connectivityStream ?? Connectivity().onConnectivityChanged,
        _backoffForAttempt = backoffForAttempt ?? defaultBackoffForAttempt,
        _observeLifecycle = observeLifecycle;

  final MediaOutboxStore store;
  final MediaBlobStore blobs;
  final DocumentPipeline pipeline;
  final void Function(MediaOutboxItem item)? onAcked;
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
          final items = store
              .pending()
              .where((e) => !e.isTerminalFailure)
              .where((e) => !attempted.contains(e.clientUploadId))
              .toList()
            ..sort((a, b) => a.createdAtIso.compareTo(b.createdAtIso));
          if (items.isEmpty) break;
          final next = items.first;
          attempted.add(next.clientUploadId);
          if (pushedInPass) {
            await Future<void>.delayed(_backoffForAttempt(next.attempts));
          }
          final stillThere =
              store.pending().any((e) => e.clientUploadId == next.clientUploadId);
          if (!stillThere) continue;
          final current = store
              .pending()
              .firstWhere((e) => e.clientUploadId == next.clientUploadId);
          if (current.isTerminalFailure) continue;
          await _pushOne(current);
          pushedInPass = true;
        }
      } while (_flushAgain);
    } finally {
      _flushing = false;
      onChanged?.call();
    }
  }

  Future<bool> _pushOne(MediaOutboxItem item) async {
    try {
      await store.update(
        item.copyWith(stage: MediaOutboxStage.uploading, uploadProgress: 0),
      );
      onChanged?.call();

      final bytes = await blobs.read(item.localPath);
      final doc = await pipeline.uploadEvidence(
        request: UploadUrlRequest(
          ownerType: item.ownerType,
          ownerId: item.ownerId,
          filename: item.filename,
          contentType: item.contentType,
          sizeBytes: bytes.length,
          category: item.category,
        ),
        bytes: bytes,
        onSendProgress: (sent, total) {
          if (total <= 0) return;
          unawaited(
            store.update(
              item.copyWith(
                stage: MediaOutboxStage.uploading,
                uploadProgress: sent / total,
                documentId: item.documentId,
              ),
            ).then((_) => onChanged?.call()),
          );
        },
      );

      await store.update(
        item.copyWith(
          documentId: doc.id,
          stage: MediaOutboxStage.finalizing,
          uploadProgress: 1,
        ),
      );
      onChanged?.call();

      final polled = await pipeline.pollScanStatus(
        documentId: doc.id,
        ownerType: item.ownerType,
        ownerId: item.ownerId,
      );
      if (polled.isScanBlocked) {
        await store.markTerminalFailure(
          item.clientUploadId,
          'scan_blocked',
        );
        onChanged?.call();
        return false;
      }

      await blobs.delete(item.localPath);
      await store.ack(item.clientUploadId);
      onAcked?.call(item.copyWith(documentId: doc.id));
      onChanged?.call();
      return true;
    } on AppFailure catch (e) {
      final code = e.statusCode;
      final terminal = code != null && code >= 400 && code < 500 && code != 408 && code != 429;
      if (terminal || e.code == 'scan_blocked') {
        await store.markTerminalFailure(
          item.clientUploadId,
          e.code.isNotEmpty ? e.code : e.message,
        );
      } else {
        await store.markAttempt(item.clientUploadId, e.message);
      }
      onChanged?.call();
      return false;
    } catch (e) {
      await store.markAttempt(item.clientUploadId, e.toString());
      onChanged?.call();
      return false;
    }
  }
}
