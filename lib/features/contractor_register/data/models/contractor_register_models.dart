/// Request body for `POST /v1/contractors/register`.
class ContractorRegisterRequest {
  const ContractorRegisterRequest({
    required this.email,
    required this.password,
    required this.termsVersion,
    required this.privacyVersion,
    this.fullName,
    this.phone,
    this.dob,
    this.abn,
    this.addressLine1,
    this.addressLine2,
    this.suburb,
    this.state,
    this.postcode,
    this.country,
    this.compliance,
    this.metadata,
    this.paymentDetails,
    this.inviteToken,
  });

  final String? fullName;
  final String email;
  final String password;
  final String? phone;

  /// ISO date `YYYY-MM-DD` when set.
  final String? dob;
  final String? abn;
  final String? addressLine1;
  final String? addressLine2;
  final String? suburb;
  final String? state;
  final String? postcode;
  final String? country;
  final Map<String, dynamic>? compliance;
  final Map<String, dynamic>? metadata;
  final ContractorRegisterPaymentDetails? paymentDetails;
  final String? inviteToken;
  final String termsVersion;
  final String privacyVersion;

  Map<String, dynamic> toJson() => {
        if (fullName != null && fullName!.trim().isNotEmpty)
          'full_name': fullName!.trim(),
        'email': email,
        'password': password,
        if (phone != null && phone!.trim().isNotEmpty) 'phone': phone!.trim(),
        if (dob != null && dob!.isNotEmpty) 'dob': dob,
        if (abn != null && abn!.isNotEmpty) 'abn': abn,
        if (addressLine1 != null && addressLine1!.trim().isNotEmpty)
          'address_line1': addressLine1!.trim(),
        if (addressLine2 != null && addressLine2!.trim().isNotEmpty)
          'address_line2': addressLine2!.trim(),
        if (suburb != null && suburb!.trim().isNotEmpty) 'suburb': suburb!.trim(),
        if (state != null && state!.trim().isNotEmpty) 'state': state!.trim(),
        if (postcode != null && postcode!.trim().isNotEmpty)
          'postcode': postcode!.trim(),
        if (country != null && country!.trim().isNotEmpty)
          'country': country!.trim(),
        if (compliance != null && compliance!.isNotEmpty)
          'compliance': compliance,
        if (metadata != null && metadata!.isNotEmpty) 'metadata': metadata,
        if (paymentDetails != null) 'payment_details': paymentDetails!.toJson(),
        if (inviteToken != null && inviteToken!.trim().isNotEmpty)
          'invite_token': inviteToken!.trim(),
        'terms_version': termsVersion,
        'privacy_version': privacyVersion,
      };
}

class ContractorRegisterPaymentDetails {
  const ContractorRegisterPaymentDetails({
    required this.accountName,
    required this.bsb,
    required this.accountNumber,
  });

  final String accountName;
  final String bsb;
  final String accountNumber;

  Map<String, dynamic> toJson() => {
        'account_name': accountName,
        'bsb': bsb,
        'account_number': accountNumber,
      };
}

/// `POST /v1/public/geocode`
class GeocodeRequest {
  const GeocodeRequest({
    required this.addressLine1,
    required this.city,
    required this.country,
    this.state,
  });

  final String addressLine1;
  final String city;
  final String country;
  final String? state;

  Map<String, dynamic> toJson() => {
        'address_line1': addressLine1,
        'city': city,
        'country': country,
        if (state != null && state!.isNotEmpty) 'state': state,
      };
}

class GeocodeResponse {
  const GeocodeResponse({
    required this.latitude,
    required this.longitude,
    this.formattedAddress,
    this.confidence,
  });

  final double latitude;
  final double longitude;
  final String? formattedAddress;
  final String? confidence;

  factory GeocodeResponse.fromJson(Map<String, dynamic> json) {
    return GeocodeResponse(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      formattedAddress: json['formatted_address'] as String?,
      confidence: json['confidence'] as String?,
    );
  }
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
