/// `GET/PATCH /v1/contractor-me` profile payload.
class ContractorMeOut {
  const ContractorMeOut({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.createdAt,
    required this.updatedAt,
    this.email,
    this.phone,
    this.dob,
    this.abn,
    this.addressLine1,
    this.addressLine2,
    this.suburb,
    this.state,
    this.postcode,
    this.country,
    this.paymentDetails,
    this.metadata = const {},
  });

  final String id;
  final String userId;
  final String fullName;
  final String? email;
  final String? phone;
  final String? dob;
  final String? abn;
  final String? addressLine1;
  final String? addressLine2;
  final String? suburb;
  final String? state;
  final String? postcode;
  final String? country;
  final ContractorPaymentDetailsOut? paymentDetails;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isProfileComplete => (abn ?? '').trim().isNotEmpty;

  Map<String, dynamic> get compliance {
    final value = metadata['compliance'];
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return const {};
  }

  factory ContractorMeOut.fromJson(Map<String, dynamic> json) {
    final payment = json['payment_details'];
    return ContractorMeOut(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      dob: json['dob']?.toString(),
      abn: json['abn'] as String?,
      addressLine1: json['address_line1'] as String?,
      addressLine2: json['address_line2'] as String?,
      suburb: json['suburb'] as String?,
      state: json['state'] as String?,
      postcode: json['postcode'] as String?,
      country: json['country'] as String?,
      paymentDetails:
          payment is Map
              ? ContractorPaymentDetailsOut.fromJson(
                Map<String, dynamic>.from(payment),
              )
              : null,
      metadata:
          json['metadata'] is Map
              ? Map<String, dynamic>.from(json['metadata'] as Map)
              : const {},
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class ContractorPaymentDetailsOut {
  const ContractorPaymentDetailsOut({
    required this.accountName,
    required this.bsb,
    required this.accountNumberMasked,
    required this.updatedAt,
  });

  final String accountName;
  final String bsb;
  final String accountNumberMasked;
  final DateTime updatedAt;

  factory ContractorPaymentDetailsOut.fromJson(Map<String, dynamic> json) {
    return ContractorPaymentDetailsOut(
      accountName: json['account_name'] as String? ?? '',
      bsb: json['bsb'] as String? ?? '',
      accountNumberMasked: json['account_number_masked'] as String? ?? '',
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class ContractorPaymentDetailsIn {
  const ContractorPaymentDetailsIn({
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
