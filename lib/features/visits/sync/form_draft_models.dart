/// B2 durable visit form draft / queued submit item.
///
/// Keyed by [visitId] + [formTemplateId] + optional [participantId]
/// (`null` = visit/group-level note).
class FormDraftItem {
  const FormDraftItem({
    required this.draftKey,
    required this.visitId,
    required this.formTemplateId,
    required this.payloadJson,
    required this.updatedAtIso,
    this.participantId,
    this.supportItemCode,
    this.clientEventId,
    this.stage = FormDraftStage.draft,
    this.attempts = 0,
    this.lastError,
    this.isTerminalFailure = false,
  });

  final String draftKey;
  final String visitId;
  final String formTemplateId;
  /// Null = visit/group-level note; set for per-participant SIL notes.
  final String? participantId;
  /// Snapshot of visit support item for roster → notes → claim identity.
  final String? supportItemCode;
  final Map<String, dynamic> payloadJson;
  final String updatedAtIso;
  /// Set when the user queues a submit (offline flush uses this as idempotency key).
  final String? clientEventId;
  final FormDraftStage stage;
  final int attempts;
  final String? lastError;
  final bool isTerminalFailure;

  static String makeKey({
    required String visitId,
    required String formTemplateId,
    String? participantId,
  }) =>
      '$visitId|$formTemplateId|${participantId ?? ''}';

  bool get hasContent => payloadJson.isNotEmpty;

  /// Unsent work that must not be wiped without logout confirm.
  bool get isUnsent =>
      stage == FormDraftStage.queued ||
      stage == FormDraftStage.failed ||
      (stage == FormDraftStage.draft && hasContent);

  Map<String, dynamic> toJson() => {
        'draft_key': draftKey,
        'visit_id': visitId,
        'form_template_id': formTemplateId,
        'participant_id': participantId,
        'support_item_code': supportItemCode,
        'payload_json': payloadJson,
        'updated_at': updatedAtIso,
        'client_event_id': clientEventId,
        'stage': stage.name,
        'attempts': attempts,
        'last_error': lastError,
        'is_terminal_failure': isTerminalFailure,
      };

  factory FormDraftItem.fromJson(Map<String, dynamic> j) {
    final rawPayload = j['payload_json'];
    return FormDraftItem(
      draftKey: j['draft_key'] as String? ??
          makeKey(
            visitId: j['visit_id'] as String,
            formTemplateId: j['form_template_id'] as String,
            participantId: j['participant_id'] as String?,
          ),
      visitId: j['visit_id'] as String,
      formTemplateId: j['form_template_id'] as String,
      participantId: j['participant_id'] as String?,
      supportItemCode: j['support_item_code'] as String?,
      payloadJson: rawPayload is Map
          ? Map<String, dynamic>.from(rawPayload)
          : <String, dynamic>{},
      updatedAtIso: j['updated_at'] as String? ??
          DateTime.now().toUtc().toIso8601String(),
      clientEventId: j['client_event_id'] as String?,
      stage: FormDraftStage.values.byName(
        j['stage'] as String? ?? FormDraftStage.draft.name,
      ),
      attempts: j['attempts'] as int? ?? 0,
      lastError: j['last_error'] as String?,
      isTerminalFailure: j['is_terminal_failure'] as bool? ?? false,
    );
  }

  FormDraftItem copyWith({
    Map<String, dynamic>? payloadJson,
    String? updatedAtIso,
    String? supportItemCode,
    String? clientEventId,
    bool clearClientEventId = false,
    FormDraftStage? stage,
    int? attempts,
    String? lastError,
    bool clearLastError = false,
    bool? isTerminalFailure,
  }) =>
      FormDraftItem(
        draftKey: draftKey,
        visitId: visitId,
        formTemplateId: formTemplateId,
        participantId: participantId,
        supportItemCode: supportItemCode ?? this.supportItemCode,
        payloadJson: payloadJson ?? this.payloadJson,
        updatedAtIso: updatedAtIso ?? this.updatedAtIso,
        clientEventId:
            clearClientEventId ? null : (clientEventId ?? this.clientEventId),
        stage: stage ?? this.stage,
        attempts: attempts ?? this.attempts,
        lastError: clearLastError ? null : (lastError ?? this.lastError),
        isTerminalFailure: isTerminalFailure ?? this.isTerminalFailure,
      );
}

enum FormDraftStage {
  /// Local autosave only — not yet submitted by the user.
  draft,

  /// User pressed submit; waiting for server ACK.
  queued,

  /// Sync failed; payload retained for retry.
  failed,
}
