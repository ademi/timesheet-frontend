import 'engagement_models.dart';

/// Staff contractor CRM create/get/patch DTOs (Phase 4).

class ContractorAddress {
  const ContractorAddress({
    this.addressLine1,
    this.addressLine2,
    this.suburb,
    this.state,
    this.postcode,
    this.country,
  });

  final String? addressLine1;
  final String? addressLine2;
  final String? suburb;
  final String? state;
  final String? postcode;
  final String? country;

  factory ContractorAddress.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ContractorAddress();
    return ContractorAddress(
      addressLine1: json['address_line1'] as String?,
      addressLine2: json['address_line2'] as String?,
      suburb: json['suburb'] as String?,
      state: json['state'] as String?,
      postcode: json['postcode'] as String?,
      country: json['country'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (addressLine1 != null && addressLine1!.trim().isNotEmpty)
          'address_line1': addressLine1!.trim(),
        if (addressLine2 != null && addressLine2!.trim().isNotEmpty)
          'address_line2': addressLine2!.trim(),
        if (suburb != null && suburb!.trim().isNotEmpty)
          'suburb': suburb!.trim(),
        if (state != null && state!.trim().isNotEmpty) 'state': state!.trim(),
        if (postcode != null && postcode!.trim().isNotEmpty)
          'postcode': postcode!.trim(),
        if (country != null && country!.trim().isNotEmpty)
          'country': country!.trim(),
      };

  bool get isEmpty => toJson().isEmpty;
}

class StaffContractorPaymentDetails {
  const StaffContractorPaymentDetails({
    required this.accountName,
    required this.bsb,
    required this.accountNumber,
  });

  final String accountName;
  final String bsb;
  final String accountNumber;

  Map<String, dynamic> toJson() => {
        'account_name': accountName.trim(),
        'bsb': bsb.trim(),
        'account_number': accountNumber.trim(),
      };
}

class StaffContractorPaymentDetailsOut {
  const StaffContractorPaymentDetailsOut({
    required this.accountName,
    required this.bsb,
    required this.accountNumberMasked,
  });

  final String accountName;
  final String bsb;
  final String accountNumberMasked;

  factory StaffContractorPaymentDetailsOut.fromJson(Map<String, dynamic> json) {
    return StaffContractorPaymentDetailsOut(
      accountName: json['account_name'] as String? ?? '',
      bsb: json['bsb'] as String? ?? '',
      accountNumberMasked: json['account_number_masked'] as String? ?? '',
    );
  }
}

class StaffContractorOut {
  const StaffContractorOut({
    required this.id,
    required this.userId,
    required this.fullName,
    this.email,
    this.phone,
    this.dob,
    this.abn,
    this.address = const ContractorAddress(),
    this.compliance = const {},
    this.metadata = const {},
    this.paymentDetails,
  });

  final String id;
  final String userId;
  final String fullName;
  final String? email;
  final String? phone;
  final DateTime? dob;
  final String? abn;
  final ContractorAddress address;
  final Map<String, dynamic> compliance;
  final Map<String, dynamic> metadata;
  final StaffContractorPaymentDetailsOut? paymentDetails;

  factory StaffContractorOut.fromJson(Map<String, dynamic> json) {
    final dobRaw = json['dob'] as String?;
    final payment = json['payment_details'];
    return StaffContractorOut(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      dob: dobRaw == null || dobRaw.isEmpty ? null : DateTime.tryParse(dobRaw),
      abn: json['abn'] as String?,
      address: ContractorAddress.fromJson(
        json['address'] is Map
            ? Map<String, dynamic>.from(json['address'] as Map)
            : null,
      ),
      compliance: json['compliance'] is Map
          ? Map<String, dynamic>.from(json['compliance'] as Map)
          : const {},
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const {},
      paymentDetails: payment is Map
          ? StaffContractorPaymentDetailsOut.fromJson(
              Map<String, dynamic>.from(payment),
            )
          : null,
    );
  }
}

class StaffContractorCreateRequest {
  const StaffContractorCreateRequest({
    required this.email,
    this.fullName,
    this.phone,
    this.dob,
    this.abn,
    this.address,
    this.compliance,
    this.requiredCategories = const [],
    this.sendInvite = true,
  });

  final String email;
  final String? fullName;
  final String? phone;
  final DateTime? dob;
  final String? abn;
  final ContractorAddress? address;
  final Map<String, dynamic>? compliance;
  final List<String> requiredCategories;
  final bool sendInvite;

  Map<String, dynamic> toJson() {
    final addr = address?.toJson() ?? {};
    return {
      'email': email.trim().toLowerCase(),
      if (fullName != null && fullName!.trim().isNotEmpty)
        'full_name': fullName!.trim(),
      if (phone != null && phone!.trim().isNotEmpty) 'phone': phone!.trim(),
      if (dob != null) 'dob': dob!.toIso8601String().split('T').first,
      if (abn != null && abn!.trim().isNotEmpty) 'abn': abn!.trim(),
      if (addr.isNotEmpty) 'address': addr,
      if (compliance != null && compliance!.isNotEmpty) 'compliance': compliance,
      'required_categories': requiredCategories,
      'send_invite': sendInvite,
    };
  }
}

class StaffContractorUpdateRequest {
  const StaffContractorUpdateRequest({
    this.fullName,
    this.phone,
    this.dob,
    this.abn,
    this.address,
    this.compliance,
    this.paymentDetails,
  });

  final String? fullName;
  final String? phone;
  final DateTime? dob;
  final String? abn;
  final ContractorAddress? address;
  final Map<String, dynamic>? compliance;
  final StaffContractorPaymentDetails? paymentDetails;

  Map<String, dynamic> toJson() {
    final addr = address?.toJson() ?? {};
    return {
      if (fullName != null && fullName!.trim().isNotEmpty)
        'full_name': fullName!.trim(),
      if (phone != null) 'phone': phone!.trim().isEmpty ? null : phone!.trim(),
      if (dob != null) 'dob': dob!.toIso8601String().split('T').first,
      if (abn != null) 'abn': abn!.trim().isEmpty ? null : abn!.trim(),
      if (addr.isNotEmpty) 'address': addr,
      if (compliance != null) 'compliance': compliance,
      if (paymentDetails != null) 'payment_details': paymentDetails!.toJson(),
    };
  }
}

class StaffContractorCreateResponse {
  const StaffContractorCreateResponse({
    required this.kind,
    this.contractor,
    this.engagement,
    this.registrationInvite,
  });

  final String kind;
  final StaffContractorOut? contractor;
  final EngagementOut? engagement;
  final ContractorRegistrationInviteOut? registrationInvite;

  bool get isRegistrationInvite => kind == 'registration_invite';

  factory StaffContractorCreateResponse.fromJson(Map<String, dynamic> json) {
    final contractor = json['contractor'];
    final invite = json['registration_invite'];
    final engagement = json['engagement'];
    return StaffContractorCreateResponse(
      kind: json['kind'] as String? ?? '',
      contractor: contractor is Map
          ? StaffContractorOut.fromJson(Map<String, dynamic>.from(contractor))
          : null,
      engagement: engagement is Map
          ? EngagementOut.fromJson(Map<String, dynamic>.from(engagement))
          : null,
      registrationInvite: invite is Map
          ? ContractorRegistrationInviteOut.fromJson(
              Map<String, dynamic>.from(invite),
            )
          : null,
    );
  }
}
