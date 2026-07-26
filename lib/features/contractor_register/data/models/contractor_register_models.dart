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
  });

  final String fullName;
  final String email;
  final String password;
  final String? phone;

  /// ISO date `YYYY-MM-DD` when set.
  final String? dob;
  final String termsVersion;
  final String privacyVersion;

  Map<String, dynamic> toJson() => {
        'full_name': fullName,
        'email': email,
        'password': password,
        if (phone != null && phone!.trim().isNotEmpty) 'phone': phone!.trim(),
        if (dob != null && dob!.isNotEmpty) 'dob': dob,
        'terms_version': termsVersion,
        'privacy_version': privacyVersion,
      };
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
