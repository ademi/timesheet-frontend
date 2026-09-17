import 'package:get/get.dart';

import '../../features/visits/sync/outbox_store.dart';
import 'auth_session_invalidation.dart';
import '../services/session_service.dart';
import '../services/token_storage.dart';

/// Clears session state and persisted auth tokens.
///
/// When the visit clock outbox has pending items, throws [StateError] with
/// message `outbox_not_empty` unless [confirmDiscardOutbox] is true (which
/// discards unsent clock events via [OutboxStore.clearDestructive]).
Future<void> clearSession({
  bool confirmDiscardOutbox = false,
  SessionService? sessionService,
  TokenStorage? tokenStorage,
  OutboxStore? outboxStore,
}) async {
  final outbox =
      outboxStore ??
      (Get.isRegistered<OutboxStore>() ? Get.find<OutboxStore>() : null);
  if (outbox != null && outbox.pending().isNotEmpty) {
    outbox.clearDestructive(confirmDiscard: confirmDiscardOutbox);
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
