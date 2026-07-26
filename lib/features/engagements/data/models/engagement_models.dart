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
  });

  final String category;
  final bool isRequired;

  factory RequiredDocCategory.fromJson(Map<String, dynamic> json) {
    return RequiredDocCategory(
      category: json['category'] as String,
      isRequired: json['is_required'] as bool? ?? true,
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
      requiredDocCategories: cats is List
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
