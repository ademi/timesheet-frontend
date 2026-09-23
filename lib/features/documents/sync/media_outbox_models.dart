/// Durable media upload outbox item (A18) — metadata in GetStorage; bytes on disk.
class MediaOutboxItem {
  const MediaOutboxItem({
    required this.clientUploadId,
    required this.ownerType,
    required this.ownerId,
    required this.filename,
    required this.contentType,
    required this.sizeBytes,
    required this.localPath,
    required this.createdAtIso,
    this.category = 'other',
    this.visitId,
    this.formTemplateId,
    this.fieldId,
    this.incidentId,
    this.documentId,
    this.stage = MediaOutboxStage.queued,
    this.uploadProgress = 0,
    this.attempts = 0,
    this.lastError,
    this.isTerminalFailure = false,
  });

  final String clientUploadId;
  final String ownerType;
  final String ownerId;
  final String filename;
  final String contentType;
  final int sizeBytes;
  final String localPath;
  final String createdAtIso;
  final String category;
  final String? visitId;
  final String? formTemplateId;
  final String? fieldId;
  final String? incidentId;
  final String? documentId;
  final MediaOutboxStage stage;
  final double uploadProgress;
  final int attempts;
  final String? lastError;
  final bool isTerminalFailure;

  Map<String, dynamic> toJson() => {
        'client_upload_id': clientUploadId,
        'owner_type': ownerType,
        'owner_id': ownerId,
        'filename': filename,
        'content_type': contentType,
        'size_bytes': sizeBytes,
        'local_path': localPath,
        'created_at': createdAtIso,
        'category': category,
        'visit_id': visitId,
        'form_template_id': formTemplateId,
        'field_id': fieldId,
        'incident_id': incidentId,
        'document_id': documentId,
        'stage': stage.name,
        'upload_progress': uploadProgress,
        'attempts': attempts,
        'last_error': lastError,
        'is_terminal_failure': isTerminalFailure,
      };

  factory MediaOutboxItem.fromJson(Map<String, dynamic> j) => MediaOutboxItem(
        clientUploadId: j['client_upload_id'] as String,
        ownerType: j['owner_type'] as String,
        ownerId: j['owner_id'] as String,
        filename: j['filename'] as String,
        contentType: j['content_type'] as String,
        sizeBytes: j['size_bytes'] as int? ?? 0,
        localPath: j['local_path'] as String,
        createdAtIso: j['created_at'] as String? ??
            DateTime.now().toUtc().toIso8601String(),
        category: j['category'] as String? ?? 'other',
        visitId: j['visit_id'] as String?,
        formTemplateId: j['form_template_id'] as String?,
        fieldId: j['field_id'] as String?,
        incidentId: j['incident_id'] as String?,
        documentId: j['document_id'] as String?,
        stage: MediaOutboxStage.values.byName(
          j['stage'] as String? ?? MediaOutboxStage.queued.name,
        ),
        uploadProgress: (j['upload_progress'] as num?)?.toDouble() ?? 0,
        attempts: j['attempts'] as int? ?? 0,
        lastError: j['last_error'] as String?,
        isTerminalFailure: j['is_terminal_failure'] as bool? ?? false,
      );

  MediaOutboxItem copyWith({
    String? documentId,
    MediaOutboxStage? stage,
    double? uploadProgress,
    int? attempts,
    String? lastError,
    bool clearLastError = false,
    bool? isTerminalFailure,
    String? localPath,
  }) =>
      MediaOutboxItem(
        clientUploadId: clientUploadId,
        ownerType: ownerType,
        ownerId: ownerId,
        filename: filename,
        contentType: contentType,
        sizeBytes: sizeBytes,
        localPath: localPath ?? this.localPath,
        createdAtIso: createdAtIso,
        category: category,
        visitId: visitId,
        formTemplateId: formTemplateId,
        fieldId: fieldId,
        incidentId: incidentId,
        documentId: documentId ?? this.documentId,
        stage: stage ?? this.stage,
        uploadProgress: uploadProgress ?? this.uploadProgress,
        attempts: attempts ?? this.attempts,
        lastError: clearLastError ? null : (lastError ?? this.lastError),
        isTerminalFailure: isTerminalFailure ?? this.isTerminalFailure,
      );
}

enum MediaOutboxStage {
  queued,
  uploading,
  finalizing,
  failed,
}
