/// Request body for `POST /v1/contractors/register`.
class ContractorRegisterRequest {
  const ContractorRegisterRequest({
    required this.fullName,
    required this.email,
    required this.password,
    required this.termsVersion,
    required this.privacyVersion,
    this.phone,
    this.dob,
    this.inviteToken,
  });

  final String fullName;
  final String email;
  final String password;
  final String? phone;

  /// ISO date `YYYY-MM-DD` when set.
  final String? dob;
  final String? inviteToken;
  final String termsVersion;
  final String privacyVersion;

  Map<String, dynamic> toJson() => {
    'full_name': fullName,
    'email': email,
    'password': password,
    if (phone != null && phone!.trim().isNotEmpty) 'phone': phone!.trim(),
    if (dob != null && dob!.isNotEmpty) 'dob': dob,
    if (inviteToken != null && inviteToken!.trim().isNotEmpty)
      'invite_token': inviteToken!.trim(),
    'terms_version': termsVersion,
    'privacy_version': privacyVersion,
  };
}

/// Public information displayed to a contractor registering from an invite.
class ContractorInvitePublicOut {
  const ContractorInvitePublicOut({
    required this.tenantName,
    required this.email,
    required this.requiredCategories,
    required this.expiresAt,
  });

  final String tenantName;
  final String email;
  final List<String> requiredCategories;
  final DateTime expiresAt;

  factory ContractorInvitePublicOut.fromJson(Map<String, dynamic> json) {
    return ContractorInvitePublicOut(
      tenantName: json['tenant_name'] as String,
      email: json['email'] as String,
      requiredCategories: (json['required_categories'] as List<dynamic>? ?? [])
          .map((category) => category.toString())
          .toList(growable: false),
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }
}

/// Response from `POST /v1/contractors/register` (no tokens).
class ContractorRegisterResponse {
  const ContractorRegisterResponse({
    required this.contractorId,
    required this.userId,
    required this.email,
  });

  final String contractorId;
  final String userId;
  final String email;

  factory ContractorRegisterResponse.fromJson(Map<String, dynamic> json) {
    return ContractorRegisterResponse(
      contractorId: json['contractor_id'].toString(),
      userId: json['user_id'].toString(),
      email: json['email'] as String,
    );
  }
}
