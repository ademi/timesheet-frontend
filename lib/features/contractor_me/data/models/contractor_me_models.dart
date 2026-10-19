/// Onboarding flag keys on `GET/PATCH /v1/contractor-me`.
abstract final class OnboardingFlagKeys {
  static const wwccApplicable = 'wwcc_applicable';
  static const qualificationsApplicable = 'qualifications_applicable';
  static const drivesParticipants = 'drives_participants';
  static const usesOwnVehicle = 'uses_own_vehicle';

  static const all = <String>[
    wwccApplicable,
    qualificationsApplicable,
    drivesParticipants,
    usesOwnVehicle,
  ];
}

/// Profile section keys for `profile_sections_touched`.
abstract final class ProfileSectionKeys {
  static const screening = 'screening';
  static const qualifications = 'qualifications';
  static const checks = 'checks';

  static const all = <String>[screening, qualifications, checks];
}

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
    this.abnComplete,
    this.profileOnboardingComplete,
    this.onboardingFlags = const {},
    this.profileSectionsTouched = const {},
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

  /// Explicit ABN completeness from API (`abn_complete`); falls back to ABN present.
  final bool? abnComplete;

  /// Full profile onboarding completeness (sections + flags + ABN).
  final bool? profileOnboardingComplete;

  /// Yes/no flags; value may be null when unanswered.
  final Map<String, bool?> onboardingFlags;

  /// Which profile sections the contractor has saved/touched.
  final Map<String, bool> profileSectionsTouched;

  /// Legacy ABN-only completeness (do **not** use for Home profile banner).
  bool get isProfileComplete => (abn ?? '').trim().isNotEmpty;

  bool get isAbnComplete => abnComplete ?? isProfileComplete;

  /// Prefer server `profile_onboarding_complete`; otherwise derive locked rule locally.
  bool get isOnboardingComplete {
    if (profileOnboardingComplete != null) return profileOnboardingComplete!;
    return _deriveOnboardingComplete();
  }

  bool _deriveOnboardingComplete() {
    for (final key in ProfileSectionKeys.all) {
      if (profileSectionsTouched[key] != true) return false;
    }
    for (final key in OnboardingFlagKeys.all) {
      if (onboardingFlags[key] == null) return false;
    }
    return isAbnComplete;
  }

  Map<String, dynamic> get compliance {
    final value = metadata['compliance'];
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return const {};
  }

  factory ContractorMeOut.fromJson(Map<String, dynamic> json) {
    final payment = json['payment_details'];
    final metadata =
        json['metadata'] is Map
            ? Map<String, dynamic>.from(json['metadata'] as Map)
            : <String, dynamic>{};

    final flags = _parseFlags(
      json['onboarding_flags'] ?? metadata['onboarding_flags'],
    );
    final touched = _parseTouched(
      json['profile_sections_touched'] ?? metadata['profile_sections_touched'],
    );

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
      metadata: metadata,
      abnComplete: json['abn_complete'] as bool?,
      profileOnboardingComplete: json['profile_onboarding_complete'] as bool?,
      onboardingFlags: flags,
      profileSectionsTouched: touched,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  static Map<String, bool?> _parseFlags(Object? raw) {
    if (raw is! Map) return const {};
    final out = <String, bool?>{};
    for (final key in OnboardingFlagKeys.all) {
      if (!raw.containsKey(key)) continue;
      final v = raw[key];
      if (v == null) {
        out[key] = null;
      } else if (v is bool) {
        out[key] = v;
      }
    }
    return out;
  }

  static Map<String, bool> _parseTouched(Object? raw) {
    if (raw is! Map) return const {};
    final out = <String, bool>{};
    for (final key in ProfileSectionKeys.all) {
      final v = raw[key];
      if (v is bool) out[key] = v;
    }
    return out;
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
