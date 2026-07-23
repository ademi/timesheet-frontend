import 'engagement_summary_model.dart';

class AuthTokenModel {
  const AuthTokenModel({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    this.mustChangePassword = false,
    this.defaultBranchId,
    this.actorType,
    this.engagements = const [],
  });

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final bool mustChangePassword;
  final String? defaultBranchId;

  /// Present on V2 login / refresh / switch-tenant responses.
  final String? actorType;

  /// Contractor engagements; empty for tenant members.
  final List<EngagementSummaryModel> engagements;

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'token_type': tokenType,
        if (actorType != null) 'actor_type': actorType,
        if (engagements.isNotEmpty)
          'engagements': engagements.map((e) => e.toJson()).toList(),
      };

  factory AuthTokenModel.fromJson(Map<String, dynamic> json) {
    final rawEngagements = json['engagements'];
    return AuthTokenModel(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      tokenType: json['token_type'] as String? ?? 'bearer',
      mustChangePassword: json['must_change_password'] as bool? ?? false,
      defaultBranchId: json['branch_id'] as String?,
      actorType: json['actor_type'] as String?,
      engagements: rawEngagements is List
          ? rawEngagements
              .whereType<Map<String, dynamic>>()
              .map(EngagementSummaryModel.fromJson)
              .toList(growable: false)
          : const [],
    );
  }
}
