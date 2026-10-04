import 'package:get_storage/get_storage.dart';

import 'form_draft_models.dart';

/// Durable visit form drafts + queued submits (B2). Same GetStorage durability
/// as [OutboxStore] — clear only on ACK or confirmed logout discard.
class FormDraftStore {
  FormDraftStore(this._box);
  final GetStorage _box;
  static const _key = 'visit_form_draft_v1';

  List<FormDraftItem> all() {
    final raw = _box.read<List>(_key) ?? const [];
    return raw
        .map((e) => FormDraftItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(growable: false);
  }

  /// Unsent drafts / queued submits (logout must prompt).
  List<FormDraftItem> pendingUnsent() =>
      all().where((e) => e.isUnsent).toList(growable: false);

  /// Items waiting for network flush (queued or failed, not terminal).
  List<FormDraftItem> pendingFlush() => all()
      .where(
        (e) =>
            !e.isTerminalFailure &&
            (e.stage == FormDraftStage.queued ||
                e.stage == FormDraftStage.failed) &&
            e.clientEventId != null,
      )
      .toList(growable: false);

  FormDraftItem? get({
    required String visitId,
    required String formTemplateId,
    String? participantId,
  }) {
    final key = FormDraftItem.makeKey(
      visitId: visitId,
      formTemplateId: formTemplateId,
      participantId: participantId,
    );
    for (final item in all()) {
      if (item.draftKey == key) return item;
    }
    return null;
  }

  Future<void> upsert(FormDraftItem item) async {
    final next = [
      for (final e in all())
        if (e.draftKey != item.draftKey) e,
      item,
    ];
    await _box.write(_key, next.map((e) => e.toJson()).toList());
  }

  /// Remove after successful server ACK (or explicit discard of one draft).
  Future<void> ack(String draftKey) async {
    final next = all().where((e) => e.draftKey != draftKey).toList();
    await _box.write(_key, next.map((e) => e.toJson()).toList());
  }

  Future<void> ackByClientEventId(String clientEventId) async {
    final next =
        all().where((e) => e.clientEventId != clientEventId).toList();
    await _box.write(_key, next.map((e) => e.toJson()).toList());
  }

  Future<void> markAttempt(String draftKey, String error) async {
    final next = all().map((e) {
      if (e.draftKey != draftKey) return e;
      return e.copyWith(
        attempts: e.attempts + 1,
        lastError: error,
        stage: FormDraftStage.failed,
      );
    }).toList();
    await _box.write(_key, next.map((e) => e.toJson()).toList());
  }

  Future<void> markTerminalFailure(String draftKey, String detail) async {
    final next = all().map((e) {
      if (e.draftKey != draftKey) return e;
      return e.copyWith(
        attempts: e.attempts + 1,
        lastError: detail,
        stage: FormDraftStage.failed,
        isTerminalFailure: true,
      );
    }).toList();
    await _box.write(_key, next.map((e) => e.toJson()).toList());
  }

  void clearDestructive({required bool confirmDiscard}) {
    if (!confirmDiscard && pendingUnsent().isNotEmpty) {
      throw StateError('form_draft_not_empty');
    }
    _box.remove(_key);
  }
}
