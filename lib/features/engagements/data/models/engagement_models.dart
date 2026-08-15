import '../../../credentials/data/models/credential_models.dart';

/// Engagement statuses returned by the API (exact strings).
const engagementStatuses = <String>[
  'invited',
  'pending_docs',
  'approved',
  'active',
  'suspended',
  'ended',
];

class RequiredDocCategory {
  const RequiredDocCategory({
    required this.category,
    required this.isRequired,
    this.label = '',
  });

  /// Stable wire code (e.g. `passport_id`) — use for API / matching.
  final String category;

  /// Human-readable display name from the API when present.
  final String label;

  final bool isRequired;

  /// Prefer API [label]; fall back to catalog / local map via [credentialTypeLabel].
  String get displayLabel =>
      label.trim().isNotEmpty ? label.trim() : credentialTypeLabel(category);

  factory RequiredDocCategory.fromJson(Map<String, dynamic> json) {
    final category = json['category'] as String;
    final label = json['label'] as String?;
    return RequiredDocCategory(
      category: category,
      isRequired: json['is_required'] as bool? ?? true,
      label:
          (label != null && label.trim().isNotEmpty)
              ? label.trim()
              : credentialTypeLabel(category),
    );
  }
}

class EngagementOut {
  const EngagementOut({
    required this.id,
    required this.tenantId,
    required this.contractorId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.tenantName,
    this.contractorName,
    this.consentedAt,
    this.consentRevokedAt,
    this.invitedByUserId,
    this.approvedByUserId,
    this.requiredDocCategories = const [],
  });

  final String id;
  final String tenantId;
  final String? tenantName;
  final String contractorId;
  final String? contractorName;
  final String status;
  final DateTime? consentedAt;
  final DateTime? consentRevokedAt;
  final String? invitedByUserId;
  final String? approvedByUserId;
  final List<RequiredDocCategory> requiredDocCategories;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isInvited => status == 'invited';
  bool get isPendingDocs => status == 'pending_docs';
  bool get isApproved => status == 'approved';
  bool get isActive => status == 'active';
  bool get isSuspended => status == 'suspended';
  bool get isEnded => status == 'ended';

  factory EngagementOut.fromJson(Map<String, dynamic> json) {
    DateTime? parseDt(Object? v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    final cats = json['required_doc_categories'];
    return EngagementOut(
      id: json['id'].toString(),
      tenantId: json['tenant_id'].toString(),
      tenantName: json['tenant_name'] as String?,
      contractorId: json['contractor_id'].toString(),
      contractorName: json['contractor_name'] as String?,
      status: json['status'] as String,
      consentedAt: parseDt(json['consented_at']),
      consentRevokedAt: parseDt(json['consent_revoked_at']),
      invitedByUserId: json['invited_by_user_id']?.toString(),
      approvedByUserId: json['approved_by_user_id']?.toString(),
      requiredDocCategories:
          cats is List
              ? cats
                  .whereType<Map>()
                  .map(
                    (e) => RequiredDocCategory.fromJson(
                      Map<String, dynamic>.from(e),
                    ),
                  )
                  .toList(growable: false)
              : const [],
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class ContractorRegistrationInviteOut {
  const ContractorRegistrationInviteOut({
    required this.id,
    required this.email,
    required this.requiredCategories,
    required this.expiresAt,
    required this.createdAt,
    this.phone,
    this.inviteUrl,
  });

  final String id;
  final String email;
  final String? phone;
  final List<String> requiredCategories;
  final DateTime expiresAt;
  final DateTime createdAt;
  final String? inviteUrl;

  factory ContractorRegistrationInviteOut.fromJson(Map<String, dynamic> json) {
    return ContractorRegistrationInviteOut(
      id: json['id'].toString(),
      email: json['email'] as String,
      phone: json['phone'] as String?,
      requiredCategories: (json['required_categories'] as List<dynamic>? ?? [])
          .map((category) => category.toString())
          .toList(growable: false),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      inviteUrl: json['invite_url'] as String?,
    );
  }
}

class EngagementInviteResponse {
  const EngagementInviteResponse({
    required this.kind,
    this.engagement,
    this.registrationInvite,
  });

  final String kind;
  final EngagementOut? engagement;
  final ContractorRegistrationInviteOut? registrationInvite;

  bool get isEngagement => kind == 'engagement';
  bool get isRegistrationInvite => kind == 'registration_invite';

  factory EngagementInviteResponse.fromJson(Map<String, dynamic> json) {
    final engagement = json['engagement'];
    final registrationInvite = json['registration_invite'];
    return EngagementInviteResponse(
      kind: json['kind'] as String,
      engagement:
          engagement is Map
              ? EngagementOut.fromJson(Map<String, dynamic>.from(engagement))
              : null,
      registrationInvite:
          registrationInvite is Map
              ? ContractorRegistrationInviteOut.fromJson(
                Map<String, dynamic>.from(registrationInvite),
              )
              : null,
    );
  }
}

class EngagementInviteRequest {
  const EngagementInviteRequest({
    this.email,
    this.phone,
    this.requiredCategories = const [],
  });

  final String? email;
  final String? phone;
  final List<String> requiredCategories;

  Map<String, dynamic> toJson() => {
    if (email != null && email!.trim().isNotEmpty) 'email': email!.trim(),
    if (phone != null && phone!.trim().isNotEmpty) 'phone': phone!.trim(),
    'required_categories': requiredCategories,
  };
}

class EngagementAcceptRequest {
  const EngagementAcceptRequest({this.allowSourceEvidence = false});

  final bool allowSourceEvidence;

  Map<String, dynamic> toJson() => {
    'allow_source_evidence': allowSourceEvidence,
  };
}

/// Categories available for invite multi-select (credential allowlist).
List<String> get inviteCategoryOptions =>
    List<String>.from(credentialTypesAllowlist);
