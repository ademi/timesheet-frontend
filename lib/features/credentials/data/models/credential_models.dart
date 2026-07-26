/// Credential allowlist + DTOs (design §6.4).
const credentialTypesAllowlist = <String>[
  'passport_id',
  'drivers_licence',
  'ndis_worker_screening',
  'police_check',
  'wwcc',
  'first_aid',
  'cpr',
  'infection_control',
  'worker_orientation',
  'abn',
  'resume',
  'cert_iii',
  'nursing_bachelor',
  'nursing_diploma',
  'other_health_qualification',
  'trade_certificate',
  'insurance',
  'other',
];

const sensitiveCredentialTypes = <String>{
  'police_check',
  'ndis_worker_screening',
  'first_aid',
  'cpr',
  'infection_control',
  'other_health_qualification',
};

const governmentIdCredentialTypes = <String>{
  'passport_id',
  'drivers_licence',
};

String credentialTypeLabel(String type) {
  return type.replaceAll('_', ' ');
}

bool isSensitiveCredentialType(String type) =>
    sensitiveCredentialTypes.contains(type);

bool isGovernmentIdCredentialType(String type) =>
    governmentIdCredentialTypes.contains(type);

class CredentialOut {
  const CredentialOut({
    required this.id,
    required this.contractorId,
    required this.credentialType,
    required this.status,
    required this.provenanceState,
    required this.evidencePresence,
    required this.createdAt,
    required this.updatedAt,
    this.issuer,
    this.jurisdiction,
    this.identifierMasked,
    this.issuedOn,
    this.completedOn,
    this.effectiveOn,
    this.expiresOn,
  });

  final String id;
  final String contractorId;
  final String credentialType;
  final String? issuer;
  final String? jurisdiction;
  final String? identifierMasked;
  final DateTime? issuedOn;
  final DateTime? completedOn;
  final DateTime? effectiveOn;
  final DateTime? expiresOn;
  final String status;
  final String provenanceState;
  final String evidencePresence;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CredentialOut.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(Object? v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    return CredentialOut(
      id: json['id'].toString(),
      contractorId: json['contractor_id'].toString(),
      credentialType: json['credential_type'] as String,
      issuer: json['issuer'] as String?,
      jurisdiction: json['jurisdiction'] as String?,
      identifierMasked: json['identifier_masked'] as String?,
      issuedOn: parseDate(json['issued_on']),
      completedOn: parseDate(json['completed_on']),
      effectiveOn: parseDate(json['effective_on']),
      expiresOn: parseDate(json['expires_on']),
      status: json['status'] as String? ?? 'unknown',
      provenanceState: json['provenance_state'] as String? ?? '',
      evidencePresence: json['evidence_presence'] as String? ?? 'absent',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class CredentialCreateRequest {
  const CredentialCreateRequest({
    required this.credentialType,
    required this.noticeEventId,
    this.jurisdiction = 'AU',
    this.issuer,
    this.identifier,
    this.issuedOn,
    this.completedOn,
    this.effectiveOn,
    this.expiresOn,
  });

  final String credentialType;
  final String noticeEventId;
  final String? jurisdiction;
  final String? issuer;
  final String? identifier;
  final DateTime? issuedOn;
  final DateTime? completedOn;
  final DateTime? effectiveOn;
  final DateTime? expiresOn;

  Map<String, dynamic> toJson() => {
        'credential_type': credentialType,
        'notice_event_id': noticeEventId,
        if (jurisdiction != null) 'jurisdiction': jurisdiction,
        if (issuer != null && issuer!.trim().isNotEmpty) 'issuer': issuer,
        if (identifier != null && identifier!.trim().isNotEmpty)
          'identifier': identifier,
        if (issuedOn != null) 'issued_on': _dateOnly(issuedOn!),
        if (completedOn != null) 'completed_on': _dateOnly(completedOn!),
        if (effectiveOn != null) 'effective_on': _dateOnly(effectiveOn!),
        if (expiresOn != null) 'expires_on': _dateOnly(expiresOn!),
      };

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

class CredentialUpdateRequest {
  const CredentialUpdateRequest({
    this.issuer,
    this.jurisdiction,
    this.issuedOn,
    this.completedOn,
    this.effectiveOn,
    this.expiresOn,
  });

  final String? issuer;
  final String? jurisdiction;
  final DateTime? issuedOn;
  final DateTime? completedOn;
  final DateTime? effectiveOn;
  final DateTime? expiresOn;

  Map<String, dynamic> toJson() => {
        if (issuer != null) 'issuer': issuer,
        if (jurisdiction != null) 'jurisdiction': jurisdiction,
        if (issuedOn != null)
          'issued_on': CredentialCreateRequest._dateOnly(issuedOn!),
        if (completedOn != null)
          'completed_on': CredentialCreateRequest._dateOnly(completedOn!),
        if (effectiveOn != null)
          'effective_on': CredentialCreateRequest._dateOnly(effectiveOn!),
        if (expiresOn != null)
          'expires_on': CredentialCreateRequest._dateOnly(expiresOn!),
      };
}

class CredentialSupersedeRequest {
  const CredentialSupersedeRequest({
    required this.noticeEventId,
    this.issuer,
    this.identifier,
    this.issuedOn,
    this.completedOn,
    this.effectiveOn,
    this.expiresOn,
  });

  final String noticeEventId;
  final String? issuer;
  final String? identifier;
  final DateTime? issuedOn;
  final DateTime? completedOn;
  final DateTime? effectiveOn;
  final DateTime? expiresOn;

  Map<String, dynamic> toJson() => {
        'notice_event_id': noticeEventId,
        if (issuer != null && issuer!.trim().isNotEmpty) 'issuer': issuer,
        if (identifier != null && identifier!.trim().isNotEmpty)
          'identifier': identifier,
        if (issuedOn != null)
          'issued_on': CredentialCreateRequest._dateOnly(issuedOn!),
        if (completedOn != null)
          'completed_on': CredentialCreateRequest._dateOnly(completedOn!),
        if (effectiveOn != null)
          'effective_on': CredentialCreateRequest._dateOnly(effectiveOn!),
        if (expiresOn != null)
          'expires_on': CredentialCreateRequest._dateOnly(expiresOn!),
      };
}

class CredentialReviewCreateRequest {
  const CredentialReviewCreateRequest({
    required this.credentialId,
    required this.decision,
    this.reasonCode,
  });

  final String credentialId;
  final String decision; // accepted | rejected | re_review_required
  final String? reasonCode;

  Map<String, dynamic> toJson() => {
        'credential_id': credentialId,
        'decision': decision,
        if (reasonCode != null && reasonCode!.trim().isNotEmpty)
          'reason_code': reasonCode,
      };
}

class CredentialReviewOut {
  const CredentialReviewOut({
    required this.id,
    required this.tenantId,
    required this.engagementId,
    required this.credentialId,
    required this.requirementCategory,
    required this.decision,
    required this.createdAt,
    required this.updatedAt,
    this.reasonCode,
    this.reviewedByUserId,
    this.decidedAt,
  });

  final String id;
  final String tenantId;
  final String engagementId;
  final String credentialId;
  final String requirementCategory;
  final String decision;
  final String? reasonCode;
  final String? reviewedByUserId;
  final DateTime? decidedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CredentialReviewOut.fromJson(Map<String, dynamic> json) {
    return CredentialReviewOut(
      id: json['id'].toString(),
      tenantId: json['tenant_id'].toString(),
      engagementId: json['engagement_id'].toString(),
      credentialId: json['credential_id'].toString(),
      requirementCategory: json['requirement_category'] as String? ?? '',
      decision: json['decision'] as String,
      reasonCode: json['reason_code'] as String?,
      reviewedByUserId: json['reviewed_by_user_id']?.toString(),
      decidedAt: json['decided_at'] != null
          ? DateTime.tryParse(json['decided_at'].toString())
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
