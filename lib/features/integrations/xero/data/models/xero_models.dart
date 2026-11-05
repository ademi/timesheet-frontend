// Xero optional payments DTOs — see docs/2026-11-02-api-handoff-fe-xero-payments.md

/// Allowed pay-band keys for pay-item mapping / export.
abstract final class XeroBandKeys {
  XeroBandKeys._();

  static const base = 'base';
  static const evening = 'evening';
  static const night = 'night';
  static const saturday = 'saturday';
  static const sunday = 'sunday';
  static const publicHoliday = 'public_holiday';

  static const all = <String>[
    base,
    evening,
    night,
    saturday,
    sunday,
    publicHoliday,
  ];
}

/// `GET /v1/integrations/xero`
class XeroConnectionStatus {
  const XeroConnectionStatus({
    required this.featureEnabled,
    required this.connected,
    required this.status,
    this.orgName,
    this.xeroTenantId,
    this.connectedAt,
    this.mappingComplete,
    this.unmappedContractorIds = const [],
    this.unmappedBandKeys = const [],
  });

  final bool featureEnabled;
  final bool connected;
  final String status;
  final String? orgName;
  final String? xeroTenantId;
  final DateTime? connectedAt;

  /// Null when disconnected; bool when connected.
  final bool? mappingComplete;
  final List<String> unmappedContractorIds;
  final List<String> unmappedBandKeys;

  bool get showXeroUi => featureEnabled && connected;

  factory XeroConnectionStatus.fromJson(Map<String, dynamic> json) {
    return XeroConnectionStatus(
      featureEnabled: json['feature_enabled'] as bool? ?? true,
      connected: json['connected'] as bool? ?? false,
      status: json['status'] as String? ?? 'disconnected',
      orgName: json['org_name'] as String?,
      xeroTenantId: json['xero_tenant_id']?.toString(),
      connectedAt:
          json['connected_at'] != null
              ? DateTime.tryParse(json['connected_at'].toString())
              : null,
      mappingComplete: json['mapping_complete'] as bool?,
      unmappedContractorIds: _stringList(json['unmapped_contractor_ids']),
      unmappedBandKeys: _stringList(json['unmapped_band_keys']),
    );
  }
}

/// `GET /v1/integrations/xero/auth-url`
class XeroAuthUrlOut {
  const XeroAuthUrlOut({required this.authorizeUrl, required this.state});

  final String authorizeUrl;
  final String state;

  factory XeroAuthUrlOut.fromJson(Map<String, dynamic> json) {
    return XeroAuthUrlOut(
      authorizeUrl: json['authorize_url'] as String? ?? '',
      state: json['state'] as String? ?? '',
    );
  }
}

/// `POST /v1/integrations/xero/disconnect`
class XeroDisconnectOut {
  const XeroDisconnectOut({
    required this.connected,
    required this.mapsRetained,
  });

  final bool connected;
  final bool mapsRetained;

  factory XeroDisconnectOut.fromJson(Map<String, dynamic> json) {
    return XeroDisconnectOut(
      connected: json['connected'] as bool? ?? false,
      mapsRetained: json['maps_retained'] as bool? ?? true,
    );
  }
}

class XeroEmployee {
  const XeroEmployee({
    required this.employeeId,
    this.firstName,
    this.lastName,
    this.status,
    this.email,
  });

  final String employeeId;
  final String? firstName;
  final String? lastName;
  final String? status;
  final String? email;

  String get displayName {
    final parts = [
      if (firstName != null && firstName!.isNotEmpty) firstName!,
      if (lastName != null && lastName!.isNotEmpty) lastName!,
    ];
    if (parts.isEmpty) return employeeId;
    return parts.join(' ');
  }

  factory XeroEmployee.fromJson(Map<String, dynamic> json) {
    return XeroEmployee(
      employeeId: json['employee_id'].toString(),
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      status: json['status'] as String?,
      email: json['email'] as String?,
    );
  }
}

class XeroEarningsRate {
  const XeroEarningsRate({
    required this.earningsRateId,
    required this.name,
    this.earningsType,
    this.rateType,
    this.currentRecord,
  });

  final String earningsRateId;
  final String name;
  final String? earningsType;
  final String? rateType;
  final bool? currentRecord;

  /// Payroll AU draft timesheets only accept ordinary/overtime earnings rates.
  bool get isTimesheetEligible {
    final t = (earningsType ?? '').toUpperCase().replaceAll(' ', '');
    return t == 'ORDINARYTIMEEARNINGS' || t == 'OVERTIMEEARNINGS';
  }

  factory XeroEarningsRate.fromJson(Map<String, dynamic> json) {
    return XeroEarningsRate(
      earningsRateId: json['earnings_rate_id'].toString(),
      name: json['name'] as String? ?? json['earnings_rate_id'].toString(),
      earningsType: json['earnings_type'] as String?,
      rateType: json['rate_type'] as String?,
      currentRecord: json['current_record'] as bool?,
    );
  }
}

class XeroEmployeeMapRow {
  const XeroEmployeeMapRow({
    required this.contractorId,
    required this.xeroEmployeeId,
  });

  final String contractorId;
  final String xeroEmployeeId;

  factory XeroEmployeeMapRow.fromJson(Map<String, dynamic> json) {
    return XeroEmployeeMapRow(
      contractorId: json['contractor_id'].toString(),
      xeroEmployeeId: json['xero_employee_id'].toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'contractor_id': contractorId,
    'xero_employee_id': xeroEmployeeId,
  };
}

class XeroEmployeeMappingsOut {
  const XeroEmployeeMappingsOut({this.employees = const []});

  final List<XeroEmployeeMapRow> employees;

  factory XeroEmployeeMappingsOut.fromJson(Map<String, dynamic> json) {
    final raw = json['employees'];
    return XeroEmployeeMappingsOut(
      employees:
          raw is List
              ? raw
                  .whereType<Map>()
                  .map(
                    (e) => XeroEmployeeMapRow.fromJson(
                      Map<String, dynamic>.from(e),
                    ),
                  )
                  .toList(growable: false)
              : const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'employees': employees.map((e) => e.toJson()).toList(growable: false),
  };
}

class XeroPayItemMapRow {
  const XeroPayItemMapRow({
    required this.bandKey,
    required this.xeroEarningsRateId,
  });

  final String bandKey;
  final String xeroEarningsRateId;

  factory XeroPayItemMapRow.fromJson(Map<String, dynamic> json) {
    return XeroPayItemMapRow(
      bandKey: json['band_key'] as String? ?? '',
      xeroEarningsRateId: json['xero_earnings_rate_id'].toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'band_key': bandKey,
    'xero_earnings_rate_id': xeroEarningsRateId,
  };
}

class XeroPayItemMappingsOut {
  const XeroPayItemMappingsOut({this.payItems = const []});

  final List<XeroPayItemMapRow> payItems;

  factory XeroPayItemMappingsOut.fromJson(Map<String, dynamic> json) {
    final raw = json['pay_items'];
    return XeroPayItemMappingsOut(
      payItems:
          raw is List
              ? raw
                  .whereType<Map>()
                  .map(
                    (e) =>
                        XeroPayItemMapRow.fromJson(Map<String, dynamic>.from(e)),
                  )
                  .toList(growable: false)
              : const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'pay_items': payItems.map((e) => e.toJson()).toList(growable: false),
  };
}

/// External timesheet ids returned on export / batch detail.
class XeroExportExternalId {
  const XeroExportExternalId({
    required this.timesheetId,
    required this.employeeId,
    required this.contractorId,
    this.status,
  });

  final String timesheetId;
  final String employeeId;
  final String contractorId;
  final String? status;

  factory XeroExportExternalId.fromJson(Map<String, dynamic> json) {
    return XeroExportExternalId(
      timesheetId: json['timesheet_id'].toString(),
      employeeId: json['employee_id'].toString(),
      contractorId: json['contractor_id'].toString(),
      status: json['status'] as String?,
    );
  }
}

/// Export fields on payment batch (also returned by export-xero).
class XeroExportResult {
  const XeroExportResult({
    required this.xeroExportStatus,
    this.xeroExportedAt,
    this.xeroExternalIds = const [],
    this.xeroLastError,
  });

  /// `not_sent` | `sent` | `failed`
  final String xeroExportStatus;
  final DateTime? xeroExportedAt;
  final List<XeroExportExternalId> xeroExternalIds;
  final String? xeroLastError;

  factory XeroExportResult.fromJson(Map<String, dynamic> json) {
    final raw = json['xero_external_ids'];
    return XeroExportResult(
      xeroExportStatus: json['xero_export_status'] as String? ?? 'not_sent',
      xeroExportedAt:
          json['xero_exported_at'] != null
              ? DateTime.tryParse(json['xero_exported_at'].toString())
              : null,
      xeroExternalIds:
          raw is List
              ? raw
                  .whereType<Map>()
                  .map(
                    (e) => XeroExportExternalId.fromJson(
                      Map<String, dynamic>.from(e),
                    ),
                  )
                  .toList(growable: false)
              : const [],
      xeroLastError: json['xero_last_error'] as String?,
    );
  }
}

List<String> _stringList(Object? raw) {
  if (raw is! List) return const [];
  return raw.map((e) => e.toString()).toList(growable: false);
}
