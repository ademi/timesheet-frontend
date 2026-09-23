import 'package:get/get.dart';

import '../../features/documents/sync/media_outbox_store.dart';
import '../../features/visits/sync/outbox_store.dart';
import 'auth_session_invalidation.dart';
import '../services/session_service.dart';
import '../services/token_storage.dart';

/// Clears session state and persisted auth tokens.
///
/// When the visit clock outbox or media outbox has pending items, throws
/// [StateError] (`outbox_not_empty` / `media_outbox_not_empty`) unless
/// [confirmDiscardOutbox] is true.
Future<void> clearSession({
  bool confirmDiscardOutbox = false,
  SessionService? sessionService,
  TokenStorage? tokenStorage,
  OutboxStore? outboxStore,
  MediaOutboxStore? mediaOutboxStore,
}) async {
  final outbox =
      outboxStore ??
      (Get.isRegistered<OutboxStore>() ? Get.find<OutboxStore>() : null);
  if (outbox != null && outbox.pending().isNotEmpty) {
    outbox.clearDestructive(confirmDiscard: confirmDiscardOutbox);
  }
  final media =
      mediaOutboxStore ??
      (Get.isRegistered<MediaOutboxStore>()
          ? Get.find<MediaOutboxStore>()
          : null);
  if (media != null && media.pending().isNotEmpty) {
    media.clearDestructive(confirmDiscard: confirmDiscardOutbox);
  }
  await invalidateStoredAuthSession(
    sessionService: sessionService,
    tokenStorage: tokenStorage,
  );
}

/// True when a registered [OutboxStore] has unsent clock events.
bool hasPendingClockOutbox({OutboxStore? outboxStore}) {
  final outbox =
      outboxStore ??
      (Get.isRegistered<OutboxStore>() ? Get.find<OutboxStore>() : null);
  return outbox != null && outbox.pending().isNotEmpty;
}

/// True when a registered [MediaOutboxStore] has unsent media uploads.
bool hasPendingMediaOutbox({MediaOutboxStore? mediaOutboxStore}) {
  final media =
      mediaOutboxStore ??
      (Get.isRegistered<MediaOutboxStore>()
          ? Get.find<MediaOutboxStore>()
          : null);
  return media != null && media.pending().isNotEmpty;
}

/// Discards pending clock outbox when [confirmDiscardOutbox] is true.
void discardClockOutboxIfConfirmed({
  required bool confirmDiscardOutbox,
  OutboxStore? outboxStore,
}) {
  if (!confirmDiscardOutbox) return;
  final outbox =
      outboxStore ??
      (Get.isRegistered<OutboxStore>() ? Get.find<OutboxStore>() : null);
  outbox?.clearDestructive(confirmDiscard: true);
}

/// Discards pending media outbox when [confirmDiscardOutbox] is true.
void discardMediaOutboxIfConfirmed({
  required bool confirmDiscardOutbox,
  MediaOutboxStore? mediaOutboxStore,
}) {
  if (!confirmDiscardOutbox) return;
  final media =
      mediaOutboxStore ??
      (Get.isRegistered<MediaOutboxStore>()
          ? Get.find<MediaOutboxStore>()
          : null);
  media?.clearDestructive(confirmDiscard: true);
}
