import '../../../../shared/utils/humanize_label.dart';

/// Credential allowlist + DTOs (design §6.4).
///
/// Wire codes are stable API values. Prefer [CredentialCategory.label] from
/// `GET /v1/credential-categories` for display; [credentialTypeLabel] falls
/// back to this map when the catalog is unavailable or a response omits label.
const credentialTypesAllowlist = <String>[
  'passport_id',
  'drivers_licence',
  'visa',
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

/// Optional pack types — uploadable but never missing-required when absent.
const optionalCredentialTypes = <String>{'visa'};

bool isOptionalCredentialType(String type) =>
    optionalCredentialTypes.contains(type);

/// Local fallback labels (offline / old API responses). Prefer catalog labels.
/// Keep Title Case to match GET /v1/credential-categories.
const credentialCategoryFallbackLabels = <String, String>{
  'passport_id': 'Photo ID / 100 Points of ID',
  'drivers_licence': 'Driver Licence',
  'visa': 'Visa / Right to Work',
  'ndis_worker_screening': 'NDIS Worker Screening Check',
  'police_check': 'National Police Check',
  'wwcc': 'Working With Children Check',
  'first_aid': 'First Aid',
  'cpr': 'CPR',
  'infection_control': 'Infection Control',
  'worker_orientation':
      'NDIS Worker Orientation Module – Quality, Safety and You',
  'ndis_induction': 'NDIS Induction',
  'effective_communication': 'Supporting Effective Communication',
  'abn': 'ABN',
  'resume': 'Resume / CV',
  'cert_iii': 'Certificate III',
  'nursing_bachelor': 'Bachelor Of Nursing',
  'nursing_diploma': 'Diploma Of Nursing',
  'other_health_qualification': 'Other Health Qualification',
  'trade_certificate': 'Trade Certificate',
  'medication_admin': 'Medication Administration',
  'epilepsy_management': 'Epilepsy Management',
  'manual_handling': 'Manual Handling',
  'vehicle_registration': 'Vehicle Registration',
  'insurance': 'Car Insurance',
  'relevant_qualification': 'Relevant qualification',
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

/// Product copy that always wins over catalog / fallback (invite UI, etc.).
const credentialCategoryDisplayOverrides = <String, String>{
  'passport_id': 'Photo ID / 100 Points of ID',
  'worker_orientation':
      'NDIS Worker Orientation Module – Quality, Safety and You',
  'visa': 'Visa / Right to Work',
};

/// Human-readable label for a credential wire code.
///
/// Order: FE display override → catalog cache → local fallback map → humanize.
String credentialTypeLabel(String type) {
  final override = credentialCategoryDisplayOverrides[type];
  if (override != null && override.isNotEmpty) return override;
  final cached = _credentialCategoryLabelCache[type];
  if (cached != null && cached.isNotEmpty) return cached;
  final fallback = credentialCategoryFallbackLabels[type];
  if (fallback != null && fallback.isNotEmpty) return fallback;
  return humanizeLabel(type);
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
    this.group,
  });

  final String code;
  final String label;
  final String? helpUrl;

  /// Optional section title from API (`group_label` / `group` / `section`).
  final String? group;

  factory CredentialCategory.fromJson(Map<String, dynamic> json) {
    final code = json['code'] as String? ?? '';
    final label = json['label'] as String?;
    final helpUrl = json['help_url'] as String?;
    final groupRaw =
        (json['group_label'] ?? json['group'] ?? json['section'])?.toString();
    final apiLabel =
        (label != null && label.trim().isNotEmpty) ? label.trim() : null;
    return CredentialCategory(
      code: code,
      // Prefer FE display overrides (e.g. Photo ID) over catalog copy.
      label:
          credentialCategoryDisplayOverrides[code] ??
          apiLabel ??
          credentialTypeLabel(code),
      helpUrl:
          (helpUrl != null && helpUrl.trim().isNotEmpty)
              ? helpUrl.trim()
              : null,
      group:
          (groupRaw != null && groupRaw.trim().isNotEmpty)
              ? groupRaw.trim()
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
    this.label,
    this.issuer,
    this.jurisdiction,
    this.identifierMasked,
    this.issuedOn,
    this.completedOn,
    this.effectiveOn,
    this.expiresOn,
    this.idPoints,
    this.reviewDecision,
    this.reviewReasonCode,
  });

  final String id;
  final String contractorId;
  final String credentialType;

  /// Optional display label from API (same catalog as credential-categories).
  final String? label;
  final String? issuer;
  final String? jurisdiction;
  final String? identifierMasked;
  final DateTime? issuedOn;
  final DateTime? completedOn;
  final DateTime? effectiveOn;
  final DateTime? expiresOn;

  /// Photo ID points (0–100) when this row contributes to 100-point ID.
  final int? idPoints;
  final String status;
  final String provenanceState;
  final String evidencePresence;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Engagement-scoped review decision from staff list (`engagement_id` query).
  /// Values: accepted | rejected | re_review_required | null.
  final String? reviewDecision;

  /// Reason from provider review (reject / re_review), when present.
  final String? reviewReasonCode;

  /// Prefer row [label] → catalog / local fallback → humanize.
  String get displayLabel {
    final fromRow = label?.trim();
    if (fromRow != null && fromRow.isNotEmpty) return fromRow;
    return credentialTypeLabel(credentialType);
  }

  factory CredentialOut.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(Object? v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    final rowLabel = json['label'] as String?;
    final reviewRaw = json['review_decision'];
    final reviewDecision =
        reviewRaw == null ? null : reviewRaw.toString().trim();
    final reasonRaw = json['review_reason_code'];
    final reviewReasonCode =
        reasonRaw == null ? null : reasonRaw.toString().trim();
    return CredentialOut(
      id: json['id'].toString(),
      contractorId: json['contractor_id'].toString(),
      credentialType: json['credential_type'] as String,
      label:
          (rowLabel != null && rowLabel.trim().isNotEmpty)
              ? rowLabel.trim()
              : null,
      issuer: json['issuer'] as String?,
      jurisdiction: json['jurisdiction'] as String?,
      identifierMasked: json['identifier_masked'] as String?,
      issuedOn: parseDate(json['issued_on']),
      completedOn: parseDate(json['completed_on']),
      effectiveOn: parseDate(json['effective_on']),
      expiresOn: parseDate(json['expires_on']),
      idPoints: () {
        final raw = json['id_points'];
        if (raw == null) return null;
        if (raw is num) return raw.toInt();
        return int.tryParse('$raw');
      }(),
      status: json['status'] as String? ?? 'unknown',
      provenanceState: json['provenance_state'] as String? ?? '',
      evidencePresence: json['evidence_presence'] as String? ?? 'absent',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      reviewDecision:
          (reviewDecision != null && reviewDecision.isNotEmpty)
              ? reviewDecision
              : null,
      reviewReasonCode:
          (reviewReasonCode != null && reviewReasonCode.isNotEmpty)
              ? reviewReasonCode
              : null,
    );
  }
}

/// Human label for provider review reason codes (WF-4).
String credentialReviewReasonLabel(String? reasonCode) {
  if (reasonCode == null || reasonCode.trim().isEmpty) return '';
  return switch (reasonCode.trim()) {
    'incomplete_evidence' => 'Incomplete evidence',
    'expired_document' => 'Expired document',
    'unreadable_scan' => 'Unreadable scan',
    'wrong_document_type' => 'Wrong document type',
    'name_mismatch' => 'Name mismatch',
    'other' => 'Other',
    final code => humanizeLabel(code),
  };
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
    this.idPoints,
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

  /// Photo ID points 0–100 (passport defaults to 100 on BE when omitted).
  final int? idPoints;

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
    if (idPoints != null) 'id_points': idPoints,
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

/// Staff audit context from `GET …/credentials-review-context`.
class CredentialReviewContextOut {
  const CredentialReviewContextOut({
    required this.credentials,
    this.documentPack,
    this.engagementId,
    this.photoIdPointsTotal,
    this.onboardingFlags = const {},
  });

  final List<CredentialOut> credentials;
  final String? documentPack;
  final String? engagementId;
  final int? photoIdPointsTotal;
  final Map<String, bool?> onboardingFlags;

  factory CredentialReviewContextOut.fromJson(Map<String, dynamic> json) {
    final creds = json['credentials'];
    final flagsRaw = json['onboarding_flags'];
    final pointsRaw = json['photo_id_points_total'];
    final flags = <String, bool?>{};
    if (flagsRaw is Map) {
      for (final entry in flagsRaw.entries) {
        final v = entry.value;
        if (v == null) {
          flags[entry.key.toString()] = null;
        } else if (v is bool) {
          flags[entry.key.toString()] = v;
        }
      }
    }
    return CredentialReviewContextOut(
      credentials:
          creds is List
              ? creds
                  .whereType<Map>()
                  .map(
                    (e) =>
                        CredentialOut.fromJson(Map<String, dynamic>.from(e)),
                  )
                  .toList(growable: false)
              : const [],
      documentPack: json['document_pack'] as String?,
      engagementId: json['engagement_id']?.toString(),
      photoIdPointsTotal:
          pointsRaw is num ? pointsRaw.toInt() : int.tryParse('$pointsRaw'),
      onboardingFlags: flags,
    );
  }
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
