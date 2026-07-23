import 'engagement_summary_model.dart';

/// Response from `GET /v1/auth/me/context`.
///
/// Contains actor + engagements — **not** permissions (those come from JWT).
class MeContextModel {
  const MeContextModel({
    required this.actorType,
    this.tenantId,
    this.contractorId,
    this.tenantMemberId,
    this.engagements = const [],
  });

  final String actorType;
  final String? tenantId;
  final String? contractorId;
  final String? tenantMemberId;
  final List<EngagementSummaryModel> engagements;

  factory MeContextModel.fromJson(Map<String, dynamic> json) {
    final rawEngagements = json['engagements'];
    return MeContextModel(
      actorType: json['actor_type'] as String,
      tenantId: json['tenant_id'] as String?,
      contractorId: json['contractor_id'] as String?,
      tenantMemberId: json['tenant_member_id'] as String?,
      engagements: rawEngagements is List
          ? rawEngagements
              .whereType<Map<String, dynamic>>()
              .map(EngagementSummaryModel.fromJson)
              .toList(growable: false)
          : const [],
    );
  }
}
