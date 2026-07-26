/// Compliance models for legal docs, notices, and legal events (S2).
class LegalDocumentCurrent {
  const LegalDocumentCurrent({
    required this.docKey,
    required this.version,
    required this.contentMd,
    required this.contentHash,
    required this.effectiveAt,
    required this.counselPending,
  });

  final String docKey;
  final String version;
  final String contentMd;
  final String contentHash;
  final DateTime effectiveAt;
  final bool counselPending;

  factory LegalDocumentCurrent.fromJson(Map<String, dynamic> json) {
    return LegalDocumentCurrent(
      docKey: json['doc_key'] as String,
      version: json['version'] as String,
      contentMd: json['content_md'] as String? ?? '',
      contentHash: json['content_hash'] as String? ?? '',
      effectiveAt: DateTime.parse(json['effective_at'] as String),
      counselPending: json['counsel_pending'] as bool? ?? false,
    );
  }
}

class CollectionNotice {
  const CollectionNotice({
    required this.noticeKey,
    required this.version,
    required this.contentMd,
    required this.contentHash,
    required this.purpose,
    required this.legalOrPolicyBasis,
    required this.consequencesOfRefusal,
    required this.retentionSummary,
    required this.counselPending,
    required this.effectiveAt,
    this.credentialType,
    this.jurisdiction,
  });

  final String noticeKey;
  final String? credentialType;
  final String? jurisdiction;
  final String version;
  final String contentMd;
  final String contentHash;
  final String purpose;
  final String legalOrPolicyBasis;
  final String consequencesOfRefusal;
  final String retentionSummary;
  final bool counselPending;
  final DateTime effectiveAt;

  factory CollectionNotice.fromJson(Map<String, dynamic> json) {
    return CollectionNotice(
      noticeKey: json['notice_key'] as String,
      credentialType: json['credential_type'] as String?,
      jurisdiction: json['jurisdiction'] as String?,
      version: json['version'] as String,
      contentMd: json['content_md'] as String? ?? '',
      contentHash: json['content_hash'] as String? ?? '',
      purpose: json['purpose'] as String? ?? '',
      legalOrPolicyBasis: json['legal_or_policy_basis'] as String? ?? '',
      consequencesOfRefusal: json['consequences_of_refusal'] as String? ?? '',
      retentionSummary: json['retention_summary'] as String? ?? '',
      counselPending: json['counsel_pending'] as bool? ?? false,
      effectiveAt: DateTime.parse(json['effective_at'] as String),
    );
  }
}

class LegalEventCreate {
  const LegalEventCreate({
    required this.eventType,
    this.docKey,
    this.version,
    this.noticeKey,
    this.noticeVersion,
    this.credentialType,
    this.dataClass,
    this.presentationSource,
    this.idempotencyKey,
  });

  final String eventType;
  final String? docKey;
  final String? version;
  final String? noticeKey;
  final String? noticeVersion;
  final String? credentialType;
  final String? dataClass;
  final String? presentationSource;
  final String? idempotencyKey;

  Map<String, dynamic> toJson() => {
        'event_type': eventType,
        if (docKey != null) 'doc_key': docKey,
        if (version != null) 'version': version,
        if (noticeKey != null) 'notice_key': noticeKey,
        if (noticeVersion != null) 'notice_version': noticeVersion,
        if (credentialType != null) 'credential_type': credentialType,
        if (dataClass != null) 'data_class': dataClass,
        if (presentationSource != null) 'presentation_source': presentationSource,
        if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      };
}

class LegalEventResult {
  const LegalEventResult({
    required this.id,
    required this.eventType,
    required this.createdAt,
  });

  final String id;
  final String eventType;
  final DateTime createdAt;

  factory LegalEventResult.fromJson(Map<String, dynamic> json) {
    return LegalEventResult(
      id: json['id'].toString(),
      eventType: json['event_type'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
