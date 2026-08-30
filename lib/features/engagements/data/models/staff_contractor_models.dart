// Staff read-only contractor profile DTO (GET /tenants/current/contractors/{id}).

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
