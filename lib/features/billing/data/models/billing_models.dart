/// NDIS catalogue search and invoice export DTOs.

/// Resolved MMM / staff override tier on export lines and visit stamps.
abstract final class PriceTier {
  PriceTier._();

  static const national = 'national';
  static const remote = 'remote';
  static const veryRemote = 'very_remote';

  static const values = {national, remote, veryRemote};

  static String labelForOverride(String? tier) {
    if (tier == null) return 'Auto (MMM postcode)';
    switch (tier) {
      case national:
        return 'National';
      case remote:
        return 'Remote';
      case veryRemote:
        return 'Very remote';
      default:
        return tier;
    }
  }

  static String sourceHint({
    required String? priceTierOverride,
    required bool lockedExported,
  }) {
    if (lockedExported) {
      return 'Locked — already included in an export.';
    }
    final override = priceTierOverride?.trim();
    if (override != null && override.isNotEmpty) {
      return 'Tier source: staff override (${labelForOverride(override)}). Wins over MMM postcode.';
    }
    return 'Tier source: Auto (MMM postcode at export). Set an override if the job location postcode is missing or wrong.';
  }
}

/// PATCH body for job or visit support item (both null clears).
class SupportItemPatch {
  const SupportItemPatch({this.supportItemCode, this.supportItemName});

  final String? supportItemCode;
  final String? supportItemName;

  Map<String, dynamic> toJson() => {
    'support_item_code': supportItemCode,
    'support_item_name': supportItemName,
  };
}

class VisitPriceTierPatch {
  const VisitPriceTierPatch({this.priceTierOverride});

  final String? priceTierOverride;

  Map<String, dynamic> toJson() => {'price_tier_override': priceTierOverride};
}

class VisitTaskBillingPatch {
  const VisitTaskBillingPatch({required this.billableMinutes});

  final int billableMinutes;

  Map<String, dynamic> toJson() => {'billable_minutes': billableMinutes};
}

/// PATCH body for visit task NDIS code (`null` clears).
class VisitTaskSupportItemPatch {
  const VisitTaskSupportItemPatch({this.supportItemCode});

  final String? supportItemCode;

  Map<String, dynamic> toJson() => {'support_item_code': supportItemCode};
}

class NdisCatalogueItemOut {
  const NdisCatalogueItemOut({
    required this.supportItemNumber,
    required this.supportItemName,
    this.supportCategoryNumber,
    this.supportCategoryName,
    this.registrationGroupNumber,
    this.registrationGroupName,
    this.unit,
    this.quoteRequired = false,
    this.priceLimitNational,
    this.priceLimitRemote,
    this.priceLimitVeryRemote,
  });

  final String supportItemNumber;
  final String supportItemName;
  final String? supportCategoryNumber;
  final String? supportCategoryName;
  final String? registrationGroupNumber;
  final String? registrationGroupName;
  final String? unit;
  final bool quoteRequired;
  final String? priceLimitNational;
  final String? priceLimitRemote;
  final String? priceLimitVeryRemote;

  factory NdisCatalogueItemOut.fromJson(Map<String, dynamic> json) {
    return NdisCatalogueItemOut(
      supportItemNumber: json['support_item_number'] as String,
      supportItemName: json['support_item_name'] as String,
      supportCategoryNumber: json['support_category_number'] as String?,
      supportCategoryName: json['support_category_name'] as String?,
      registrationGroupNumber: json['registration_group_number'] as String?,
      registrationGroupName: json['registration_group_name'] as String?,
      unit: json['unit'] as String?,
      quoteRequired: json['quote_required'] as bool? ?? false,
      priceLimitNational: json['price_limit_national']?.toString(),
      priceLimitRemote: json['price_limit_remote']?.toString(),
      priceLimitVeryRemote: json['price_limit_very_remote']?.toString(),
    );
  }
}

class NdisCatalogueSearchResponse {
  const NdisCatalogueSearchResponse({
    required this.q,
    required this.limit,
    required this.items,
  });

  final String q;
  final int limit;
  final List<NdisCatalogueItemOut> items;

  factory NdisCatalogueSearchResponse.fromJson(Map<String, dynamic> json) {
    return NdisCatalogueSearchResponse(
      q: json['q'] as String? ?? '',
      limit: json['limit'] as int? ?? 20,
      items: (json['items'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (e) => NdisCatalogueItemOut.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(growable: false),
    );
  }
}

class InvoiceExportCreateRequest {
  const InvoiceExportCreateRequest({required this.visitIds});

  final List<String> visitIds;

  Map<String, dynamic> toJson() => {'visit_ids': visitIds};
}

class InvoiceExportVisitError {
  const InvoiceExportVisitError({
    required this.visitId,
    required this.code,
    required this.message,
  });

  final String visitId;
  final String code;
  final String message;
}

class InvoiceExportLineOut {
  const InvoiceExportLineOut({
    required this.id,
    required this.visitId,
    required this.supportItemNumber,
    required this.supportItemName,
    required this.serviceDate,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.lineAmount,
    this.clientId,
    this.clientName,
    this.participantNdisNumber,
    this.priceTier,
    this.visitTaskId,
    this.shiftParticipantId,
  });

  final String id;
  final String visitId;
  final String? clientId;
  final String? clientName;
  final String? participantNdisNumber;
  final String supportItemNumber;
  final String supportItemName;
  final DateTime serviceDate;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double lineAmount;
  final String? priceTier;
  final String? visitTaskId;
  final String? shiftParticipantId;

  factory InvoiceExportLineOut.fromJson(Map<String, dynamic> json) {
    return InvoiceExportLineOut(
      id: json['id'].toString(),
      visitId: json['visit_id'].toString(),
      clientId: json['client_id']?.toString(),
      clientName: json['client_name'] as String?,
      participantNdisNumber: json['participant_ndis_number'] as String?,
      supportItemNumber: json['support_item_number'] as String,
      supportItemName: json['support_item_name'] as String,
      serviceDate: DateTime.parse(json['service_date'] as String),
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String,
      unitPrice: (json['unit_price'] as num).toDouble(),
      lineAmount: (json['line_amount'] as num).toDouble(),
      priceTier: json['price_tier'] as String?,
      visitTaskId: json['visit_task_id']?.toString(),
      shiftParticipantId: json['shift_participant_id']?.toString(),
    );
  }
}

class BudgetWarningOut {
  const BudgetWarningOut({
    required this.code,
    this.clientId,
    this.envelope,
    this.lineAmount,
    this.remainingBefore,
    this.remainingAfter,
    this.supportItemNumber,
    this.supportCategoryNumber,
  });

  final String code;
  final String? clientId;
  final String? envelope;
  final double? lineAmount;
  final double? remainingBefore;
  final double? remainingAfter;
  final String? supportItemNumber;
  final String? supportCategoryNumber;

  factory BudgetWarningOut.fromJson(Map<String, dynamic> json) {
    return BudgetWarningOut(
      code: json['code']?.toString() ?? '',
      clientId: json['client_id']?.toString(),
      envelope: json['envelope']?.toString(),
      lineAmount: (json['line_amount'] as num?)?.toDouble(),
      remainingBefore: (json['remaining_before'] as num?)?.toDouble(),
      remainingAfter: (json['remaining_after'] as num?)?.toDouble(),
      supportItemNumber: json['support_item_number']?.toString(),
      supportCategoryNumber: json['support_category_number']?.toString(),
    );
  }
}

class InvoiceExportOut {
  const InvoiceExportOut({
    required this.id,
    required this.tenantId,
    required this.status,
    required this.lineCount,
    required this.totalAmount,
    required this.currencyCode,
    required this.createdAt,
    required this.updatedAt,
    this.catalogueReleaseId,
    this.createdByUserId,
    this.finalizedAt,
    this.lines = const [],
    this.budgetWarnings = const [],
  });

  final String id;
  final String tenantId;
  final String status;
  final int lineCount;
  final double totalAmount;
  final String currencyCode;
  final String? catalogueReleaseId;
  final String? createdByUserId;
  final DateTime? finalizedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<InvoiceExportLineOut> lines;
  final List<BudgetWarningOut> budgetWarnings;

  bool get isVoid => status == 'void';
  bool get isFinalized => status == 'finalized';

  factory InvoiceExportOut.fromJson(Map<String, dynamic> json) {
    return InvoiceExportOut(
      id: json['id'].toString(),
      tenantId: json['tenant_id'].toString(),
      status: json['status'] as String,
      lineCount: json['line_count'] as int? ?? 0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      currencyCode: json['currency_code'] as String? ?? 'AUD',
      catalogueReleaseId: json['catalogue_release_id']?.toString(),
      createdByUserId: json['created_by_user_id']?.toString(),
      finalizedAt:
          json['finalized_at'] != null
              ? DateTime.tryParse(json['finalized_at'].toString())
              : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      lines: (json['lines'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (e) => InvoiceExportLineOut.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(growable: false),
      budgetWarnings: (json['budget_warnings'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => BudgetWarningOut.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
    );
  }
}

/// Completed unpaid visit not yet exported — 90-day claim window risk (A2).
class UnclaimedAgeingVisitOut {
  const UnclaimedAgeingVisitOut({
    required this.visitId,
    required this.jobId,
    required this.contractorId,
    required this.completedAt,
    required this.daysSinceCompleted,
    required this.riskBand,
    required this.paymentStatus,
    required this.invoiceStatus,
    this.jobTitle,
    this.clientId,
    this.clientName,
    this.branchId,
    this.branchName,
    this.contractorName,
    this.supportItemCode,
  });

  final String visitId;
  final String jobId;
  final String? jobTitle;
  final String? clientId;
  final String? clientName;
  final String? branchId;
  final String? branchName;
  final String contractorId;
  final String? contractorName;
  final DateTime completedAt;
  final int daysSinceCompleted;
  final String riskBand;
  final String paymentStatus;
  final String invoiceStatus;
  final String? supportItemCode;

  bool get isWatchOrWorse =>
      riskBand == 'watch' || riskBand == 'high' || riskBand == 'critical';

  factory UnclaimedAgeingVisitOut.fromJson(Map<String, dynamic> json) {
    return UnclaimedAgeingVisitOut(
      visitId: json['visit_id'].toString(),
      jobId: json['job_id'].toString(),
      jobTitle: json['job_title'] as String?,
      clientId: json['client_id']?.toString(),
      clientName: json['client_name'] as String?,
      branchId: json['branch_id']?.toString(),
      branchName: json['branch_name'] as String?,
      contractorId: json['contractor_id'].toString(),
      contractorName: json['contractor_name'] as String?,
      completedAt: DateTime.parse(json['completed_at'] as String),
      daysSinceCompleted: json['days_since_completed'] as int? ?? 0,
      riskBand: json['risk_band'] as String? ?? 'ok',
      paymentStatus: json['payment_status'] as String? ?? 'unpaid',
      invoiceStatus: json['invoice_status'] as String? ?? 'pending',
      supportItemCode: json['support_item_code'] as String?,
    );
  }
}

class BurnEnvelopeAlertOut {
  const BurnEnvelopeAlertOut({
    required this.clientId,
    required this.envelope,
    required this.severity,
    this.clientName,
    this.declared,
    this.spent = 0,
    this.remaining,
    this.remainingPct,
  });

  final String clientId;
  final String? clientName;
  final String envelope;
  final String severity;
  final double? declared;
  final double spent;
  final double? remaining;
  final double? remainingPct;

  bool get isHard => severity == 'hard_block';
  bool get isSoft => severity == 'soft_warn';

  factory BurnEnvelopeAlertOut.fromJson(Map<String, dynamic> json) {
    return BurnEnvelopeAlertOut(
      clientId: json['client_id'].toString(),
      clientName: json['client_name'] as String?,
      envelope: json['envelope'] as String? ?? '',
      severity: json['severity'] as String? ?? 'ok',
      declared: (json['declared'] as num?)?.toDouble(),
      spent: (json['spent'] as num?)?.toDouble() ?? 0,
      remaining: (json['remaining'] as num?)?.toDouble(),
      remainingPct: (json['remaining_pct'] as num?)?.toDouble(),
    );
  }
}

class PublishBurnLineOut {
  const PublishBurnLineOut({
    required this.participantId,
    required this.envelope,
    required this.estimatedAmount,
    required this.severity,
    this.clientId,
    this.clientName,
    this.remainingBefore,
    this.remainingAfter,
    this.supportItemNumber,
  });

  final String participantId;
  final String? clientId;
  final String? clientName;
  final String envelope;
  final double estimatedAmount;
  final double? remainingBefore;
  final double? remainingAfter;
  final String severity;
  final String? supportItemNumber;

  factory PublishBurnLineOut.fromJson(Map<String, dynamic> json) {
    return PublishBurnLineOut(
      participantId: json['participant_id'].toString(),
      clientId: json['client_id']?.toString(),
      clientName: json['client_name'] as String?,
      envelope: json['envelope'] as String? ?? '',
      estimatedAmount: (json['estimated_amount'] as num?)?.toDouble() ?? 0,
      remainingBefore: (json['remaining_before'] as num?)?.toDouble(),
      remainingAfter: (json['remaining_after'] as num?)?.toDouble(),
      severity: json['severity'] as String? ?? 'ok',
      supportItemNumber: json['support_item_number'] as String?,
    );
  }
}

class PublishBurnReportOut {
  const PublishBurnReportOut({
    this.softWarns = const [],
    this.hardBlocks = const [],
    this.byParticipant = const [],
    this.paceOutsideRelease = false,
    this.paceMessage,
  });

  final List<PublishBurnLineOut> softWarns;
  final List<PublishBurnLineOut> hardBlocks;
  final List<PublishBurnLineOut> byParticipant;
  final bool paceOutsideRelease;
  final String? paceMessage;

  bool get hasAnyWarn =>
      softWarns.isNotEmpty || hardBlocks.isNotEmpty || paceOutsideRelease;

  factory PublishBurnReportOut.fromJson(Map<String, dynamic> json) {
    List<PublishBurnLineOut> parseList(Object? raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map(
            (e) => PublishBurnLineOut.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(growable: false);
    }

    return PublishBurnReportOut(
      softWarns: parseList(json['soft_warns']),
      hardBlocks: parseList(json['hard_blocks']),
      byParticipant: parseList(json['by_participant']),
      paceOutsideRelease: json['pace_outside_release'] as bool? ?? false,
      paceMessage: json['pace_message'] as String?,
    );
  }
}

class PaymentEnquiryOut {
  const PaymentEnquiryOut({
    required this.id,
    required this.clientId,
    required this.status,
    required this.lodgedAt,
    required this.daysOpen,
    required this.riskBand,
    this.clientName,
    this.exportId,
    this.reference,
    this.amount,
    this.notes,
  });

  final String id;
  final String clientId;
  final String? clientName;
  final String? exportId;
  final String? reference;
  final String status;
  final DateTime lodgedAt;
  final double? amount;
  final String? notes;
  final int daysOpen;
  final String riskBand;

  factory PaymentEnquiryOut.fromJson(Map<String, dynamic> json) {
    return PaymentEnquiryOut(
      id: json['id'].toString(),
      clientId: json['client_id'].toString(),
      clientName: json['client_name'] as String?,
      exportId: json['export_id']?.toString(),
      reference: json['reference'] as String?,
      status: json['status'] as String? ?? 'open',
      lodgedAt: DateTime.parse(json['lodged_at'] as String),
      amount: (json['amount'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      daysOpen: json['days_open'] as int? ?? 0,
      riskBand: json['risk_band'] as String? ?? 'ok',
    );
  }
}

/// B16 — finalized unpaid invoice AR (5/7/14 SLA). Distinct from PE / 90d unclaimed.
class ArAgeingExportOut {
  const ArAgeingExportOut({
    required this.exportId,
    required this.status,
    required this.arPaymentStatus,
    required this.lineCount,
    required this.totalAmount,
    required this.currencyCode,
    required this.daysOpen,
    required this.riskBand,
    this.delayReason,
    this.managementType,
    this.destinationProfileId,
    this.destinationProfileName,
    this.finalizedAt,
  });

  final String exportId;
  final String status;
  final String arPaymentStatus;
  final String? delayReason;
  final String? managementType;
  final String? destinationProfileId;
  final String? destinationProfileName;
  final int lineCount;
  final double totalAmount;
  final String currencyCode;
  final DateTime? finalizedAt;
  final int daysOpen;
  final String riskBand;

  bool get isWatchOrWorse =>
      riskBand == 'watch' || riskBand == 'high' || riskBand == 'critical';

  factory ArAgeingExportOut.fromJson(Map<String, dynamic> json) {
    return ArAgeingExportOut(
      exportId: json['export_id'].toString(),
      status: json['status'] as String? ?? 'finalized',
      arPaymentStatus: json['ar_payment_status'] as String? ?? 'unpaid',
      delayReason: json['delay_reason'] as String?,
      managementType: json['management_type'] as String?,
      destinationProfileId: json['destination_profile_id']?.toString(),
      destinationProfileName: json['destination_profile_name'] as String?,
      lineCount: json['line_count'] as int? ?? 0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      currencyCode: json['currency_code'] as String? ?? 'AUD',
      finalizedAt:
          json['finalized_at'] != null
              ? DateTime.tryParse(json['finalized_at'].toString())
              : null,
      daysOpen: json['days_open'] as int? ?? 0,
      riskBand: json['risk_band'] as String? ?? 'ok',
    );
  }
}
