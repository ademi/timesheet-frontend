/// Client CRM DTOs matching `/v1/clients` (+ public invite) schemas.
class ClientOut {
  const ClientOut({
    required this.id,
    required this.tenantId,
    required this.fullName,
    required this.status,
    required this.metadata,
    required this.createdAt,
    required this.updatedAt,
    this.email,
    this.phone,
    this.serviceAgreementNotes,
  });

  final String id;
  final String tenantId;
  final String fullName;
  final String status; // active | inactive
  final String? email;
  final String? phone;
  final String? serviceAgreementNotes;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ClientOut.fromJson(Map<String, dynamic> json) {
    final meta = json['metadata'];
    return ClientOut(
      id: json['id'].toString(),
      tenantId: json['tenant_id'].toString(),
      fullName: json['full_name'] as String,
      status: json['status'] as String? ?? 'active',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      serviceAgreementNotes: json['service_agreement_notes'] as String?,
      metadata: meta is Map
          ? Map<String, dynamic>.from(meta)
          : const <String, dynamic>{},
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class ClientCreateRequest {
  const ClientCreateRequest({
    required this.fullName,
    this.status = 'active',
    this.email,
    this.phone,
    this.serviceAgreementNotes,
  });

  final String fullName;
  final String status;
  final String? email;
  final String? phone;
  final String? serviceAgreementNotes;

  Map<String, dynamic> toJson() => {
        'full_name': fullName,
        'status': status,
        if (email != null && email!.trim().isNotEmpty) 'email': email!.trim(),
        if (phone != null && phone!.trim().isNotEmpty) 'phone': phone!.trim(),
        if (serviceAgreementNotes != null)
          'service_agreement_notes': serviceAgreementNotes,
      };
}

class ClientUpdateRequest {
  const ClientUpdateRequest({
    this.fullName,
    this.status,
    this.email,
    this.phone,
    this.serviceAgreementNotes,
  });

  final String? fullName;
  final String? status;
  final String? email;
  final String? phone;
  final String? serviceAgreementNotes;

  Map<String, dynamic> toJson() => {
        if (fullName != null) 'full_name': fullName,
        if (status != null) 'status': status,
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
        if (serviceAgreementNotes != null)
          'service_agreement_notes': serviceAgreementNotes,
      };
}

class ClientSiteOut {
  const ClientSiteOut({
    required this.id,
    required this.tenantId,
    required this.clientId,
    required this.name,
    required this.geofenceRadiusM,
    required this.isPrimary,
    required this.createdAt,
    required this.updatedAt,
    this.addressLine1,
    this.city,
    this.state,
    this.country,
    this.postalCode,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String tenantId;
  final String clientId;
  final String name;
  final String? addressLine1;
  final String? city;
  final String? state;
  final String? country;
  final String? postalCode;
  final double? latitude;
  final double? longitude;
  final int geofenceRadiusM;
  final bool isPrimary;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasCoordinates => latitude != null && longitude != null;

  factory ClientSiteOut.fromJson(Map<String, dynamic> json) {
    return ClientSiteOut(
      id: json['id'].toString(),
      tenantId: json['tenant_id'].toString(),
      clientId: json['client_id'].toString(),
      name: json['name'] as String,
      addressLine1: json['address_line1'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      country: json['country'] as String?,
      postalCode: json['postal_code'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      geofenceRadiusM: json['geofence_radius_m'] as int? ?? 100,
      isPrimary: json['is_primary'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class ClientSiteWriteRequest {
  const ClientSiteWriteRequest({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.addressLine1,
    this.city,
    this.state,
    this.country,
    this.postalCode,
    this.geofenceRadiusM = 100,
    this.isPrimary = false,
  });

  final String name;
  final String? addressLine1;
  final String? city;
  final String? state;
  final String? country;
  final String? postalCode;
  final double latitude;
  final double longitude;
  final int geofenceRadiusM;
  final bool isPrimary;

  Map<String, dynamic> toJson() => {
        'name': name,
        if (addressLine1 != null) 'address_line1': addressLine1,
        if (city != null) 'city': city,
        if (state != null) 'state': state,
        if (country != null) 'country': country,
        if (postalCode != null) 'postal_code': postalCode,
        'latitude': latitude,
        'longitude': longitude,
        'geofence_radius_m': geofenceRadiusM,
        'is_primary': isPrimary,
      };
}

class ClientContactOut {
  const ClientContactOut({
    required this.id,
    required this.tenantId,
    required this.clientId,
    required this.isPrimary,
    required this.notifyVisitComplete,
    this.name,
    this.email,
    this.phone,
  });

  final String id;
  final String tenantId;
  final String clientId;
  final String? name;
  final String? email;
  final String? phone;
  final bool isPrimary;
  final bool notifyVisitComplete;

  factory ClientContactOut.fromJson(Map<String, dynamic> json) {
    return ClientContactOut(
      id: json['id'].toString(),
      tenantId: json['tenant_id'].toString(),
      clientId: json['client_id'].toString(),
      name: json['name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      isPrimary: json['is_primary'] as bool? ?? false,
      notifyVisitComplete: json['notify_visit_complete'] as bool? ?? true,
    );
  }
}

class ClientContactWriteRequest {
  const ClientContactWriteRequest({
    this.name,
    this.email,
    this.phone,
    this.isPrimary = false,
    this.notifyVisitComplete = true,
  });

  final String? name;
  final String? email;
  final String? phone;
  final bool isPrimary;
  final bool notifyVisitComplete;

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
        'is_primary': isPrimary,
        'notify_visit_complete': notifyVisitComplete,
      };
}

class ClientInviteCreateResponse {
  const ClientInviteCreateResponse({
    required this.token,
    required this.expiresAt,
  });

  final String token;
  final DateTime expiresAt;

  factory ClientInviteCreateResponse.fromJson(Map<String, dynamic> json) {
    return ClientInviteCreateResponse(
      token: json['token'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }
}

/// Staff list row (`GET /v1/clients/{id}/invites`) — no raw token.
class ClientInviteOut {
  const ClientInviteOut({
    required this.id,
    required this.expiresAt,
    required this.createdAt,
    this.consumedAt,
    this.createdByUserId,
  });

  final String id;
  final DateTime expiresAt;
  final DateTime? consumedAt;
  final DateTime createdAt;
  final String? createdByUserId;

  bool get isConsumed => consumedAt != null;
  bool get isExpired =>
      !isConsumed && expiresAt.toUtc().isBefore(DateTime.now().toUtc());

  String get statusLabel {
    if (isConsumed) return 'Consumed';
    if (isExpired) return 'Expired';
    return 'Outstanding';
  }

  factory ClientInviteOut.fromJson(Map<String, dynamic> json) {
    return ClientInviteOut(
      id: json['id'].toString(),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      consumedAt: json['consumed_at'] != null
          ? DateTime.tryParse(json['consumed_at'].toString())
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      createdByUserId: json['created_by_user_id']?.toString(),
    );
  }
}

class ClientInvitePublicOut {
  const ClientInvitePublicOut({
    required this.tenantName,
    required this.clientFirstName,
    required this.expiresAt,
    required this.consentAcknowledged,
  });

  final String tenantName;
  final String clientFirstName;
  final DateTime expiresAt;
  final bool consentAcknowledged;

  factory ClientInvitePublicOut.fromJson(Map<String, dynamic> json) {
    return ClientInvitePublicOut(
      tenantName: json['tenant_name'] as String? ?? '',
      clientFirstName: json['client_first_name'] as String? ?? '',
      expiresAt: DateTime.parse(json['expires_at'] as String),
      consentAcknowledged: json['consent_acknowledged'] as bool? ?? false,
    );
  }
}

class ClientInviteAcknowledgeResponse {
  const ClientInviteAcknowledgeResponse({
    required this.message,
    required this.consentAcknowledgedAt,
  });

  final String message;
  final String consentAcknowledgedAt;

  factory ClientInviteAcknowledgeResponse.fromJson(Map<String, dynamic> json) {
    return ClientInviteAcknowledgeResponse(
      message: json['message'] as String? ?? 'Acknowledged',
      consentAcknowledgedAt:
          json['consent_acknowledged_at']?.toString() ?? '',
    );
  }
}
