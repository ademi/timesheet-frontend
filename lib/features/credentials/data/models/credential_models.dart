/// Credential allowlist + DTOs (design §6.4).
///
/// Wire codes are stable API values. Prefer [CredentialCategory.label] from
/// `GET /v1/credential-categories` for display; [credentialTypeLabel] falls
/// back to this map when the catalog is unavailable or a response omits label.
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
  'ndis_induction',
  'effective_communication',
  'resume',
  'cert_iii',
  'nursing_bachelor',
  'nursing_diploma',
  'other_health_qualification',
  'trade_certificate',
  'medication_admin',
  'epilepsy_management',
  'manual_handling',
  'vehicle_registration',
  'insurance',
  'other',
];

/// Local fallback labels (offline / old API responses). Prefer catalog labels.
const credentialCategoryFallbackLabels = <String, String>{
  'passport_id': 'Passport',
  'drivers_licence': 'Driver licence',
  'ndis_worker_screening': 'NDIS Worker Screening Check',
  'police_check': 'National Police Check',
  'wwcc': 'Working with Children Check',
  'first_aid': 'First aid',
  'cpr': 'CPR',
  'infection_control': 'Infection control',
  'worker_orientation': 'Worker orientation',
  'ndis_induction': 'NDIS induction',
  'effective_communication': 'Supporting effective communication',
  'abn': 'ABN',
  'resume': 'Resume / CV',
  'cert_iii': 'Certificate III',
  'nursing_bachelor': 'Bachelor of Nursing',
  'nursing_diploma': 'Diploma of Nursing',
  'other_health_qualification': 'Other health qualification',
  'trade_certificate': 'Trade certificate',
  'medication_admin': 'Medication administration',
  'epilepsy_management': 'Epilepsy management',
  'manual_handling': 'Manual handling',
  'vehicle_registration': 'Vehicle registration',
  'insurance': 'Car insurance',
  'other': 'Other',
};

const sensitiveCredentialTypes = <String>{
  'police_check',
  'ndis_worker_screening',
  'first_aid',
  'cpr',
  'infection_control',
  'other_health_qualification',
};

const governmentIdCredentialTypes = <String>{'passport_id', 'drivers_licence'};

/// Runtime labels from the last successful catalog fetch (code → label).
final Map<String, String> _credentialCategoryLabelCache = {};

/// Runtime help URLs from the last successful catalog fetch (code → url).
final Map<String, String> _credentialCategoryHelpUrlCache = {};

/// Cache labels from [GET /v1/credential-categories] for app-wide display.
void cacheCredentialCategoryLabels(Iterable<CredentialCategory> categories) {
  for (final category in categories) {
    if (category.code.isEmpty || category.label.isEmpty) continue;
    _credentialCategoryLabelCache[category.code] = category.label;
    final helpUrl = category.helpUrl?.trim();
    if (helpUrl != null && helpUrl.isNotEmpty) {
      _credentialCategoryHelpUrlCache[category.code] = helpUrl;
    }
  }
}

/// Clears cached catalog labels (tests / logout).
void clearCredentialCategoryLabelCache() {
  _credentialCategoryLabelCache.clear();
  _credentialCategoryHelpUrlCache.clear();
}

/// Human-readable label for a credential wire code.
///
/// Order: catalog cache → local fallback map → prettified code.
String credentialTypeLabel(String type) {
  final cached = _credentialCategoryLabelCache[type];
  if (cached != null && cached.isNotEmpty) return cached;
  final fallback = credentialCategoryFallbackLabels[type];
  if (fallback != null && fallback.isNotEmpty) return fallback;
  return type.replaceAll('_', ' ');
}

/// External help link for obtaining a credential, when provided by the catalog.
String? credentialTypeHelpUrl(String type) {
  final cached = _credentialCategoryHelpUrlCache[type];
  if (cached != null && cached.isNotEmpty) return cached;
  return null;
}

/// Catalog entry from `GET /v1/credential-categories`.
class CredentialCategory {
  const CredentialCategory({
    required this.code,
    required this.label,
    this.helpUrl,
  });

  final String code;
  final String label;
  final String? helpUrl;

  factory CredentialCategory.fromJson(Map<String, dynamic> json) {
    final code = json['code'] as String? ?? '';
    final label = json['label'] as String?;
    final helpUrl = json['help_url'] as String?;
    return CredentialCategory(
      code: code,
      label:
          (label != null && label.trim().isNotEmpty)
              ? label.trim()
              : credentialTypeLabel(code),
      helpUrl:
          (helpUrl != null && helpUrl.trim().isNotEmpty)
              ? helpUrl.trim()
              : null,
    );
  }
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
    required this.evidenceDocumentIds,
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
  final List<String> evidenceDocumentIds;
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
    'evidence_document_ids': evidenceDocumentIds,
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
      decidedAt:
          json['decided_at'] != null
              ? DateTime.tryParse(json['decided_at'].toString())
              : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
