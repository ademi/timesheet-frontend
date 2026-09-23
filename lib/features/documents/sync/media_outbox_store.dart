import 'package:get_storage/get_storage.dart';

import 'media_outbox_models.dart';

/// Durable media upload queue metadata (A18). Bytes live on disk via [localPath].
class MediaOutboxStore {
  MediaOutboxStore(this._box);
  final GetStorage _box;
  static const _key = 'media_upload_outbox_v1';

  List<MediaOutboxItem> pending() {
    final raw = _box.read<List>(_key) ?? const [];
    return raw
        .map(
          (e) => MediaOutboxItem.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList(growable: false);
  }

  Future<void> append(MediaOutboxItem item) async {
    final next = [...pending(), item];
    await _box.write(_key, next.map((e) => e.toJson()).toList());
  }

  Future<void> ack(String clientUploadId) async {
    final next =
        pending().where((e) => e.clientUploadId != clientUploadId).toList();
    await _box.write(_key, next.map((e) => e.toJson()).toList());
  }

  Future<void> update(MediaOutboxItem item) async {
    final next = pending().map((e) {
      if (e.clientUploadId != item.clientUploadId) return e;
      return item;
    }).toList();
    await _box.write(_key, next.map((e) => e.toJson()).toList());
  }

  Future<void> markAttempt(String clientUploadId, String error) async {
    final next = pending().map((e) {
      if (e.clientUploadId != clientUploadId) return e;
      return e.copyWith(
        attempts: e.attempts + 1,
        lastError: error,
        stage: MediaOutboxStage.failed,
      );
    }).toList();
    await _box.write(_key, next.map((e) => e.toJson()).toList());
  }

  Future<void> markTerminalFailure(String clientUploadId, String detail) async {
    final next = pending().map((e) {
      if (e.clientUploadId != clientUploadId) return e;
      return e.copyWith(
        attempts: e.attempts + 1,
        lastError: detail,
        stage: MediaOutboxStage.failed,
        isTerminalFailure: true,
      );
    }).toList();
    await _box.write(_key, next.map((e) => e.toJson()).toList());
  }

  Future<void> dismissTerminal(String clientUploadId) async {
    final next = pending()
        .where(
          (e) => !(e.clientUploadId == clientUploadId && e.isTerminalFailure),
        )
        .toList();
    await _box.write(_key, next.map((e) => e.toJson()).toList());
  }

  void clearDestructive({required bool confirmDiscard}) {
    if (!confirmDiscard && pending().isNotEmpty) {
      throw StateError('media_outbox_not_empty');
    }
    _box.remove(_key);
  }
}
