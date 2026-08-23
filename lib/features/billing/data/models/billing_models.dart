/// NDIS catalogue search and invoice export DTOs.

/// Resolved MMM / staff override tier on export lines and visit stamps.
abstract final class PriceTier {
  PriceTier._();

  static const national = 'national';
  static const remote = 'remote';
  static const veryRemote = 'very_remote';

  static const values = {national, remote, veryRemote};
}

/// PATCH body for job or visit support item (both null clears).
class SupportItemPatch {
  const SupportItemPatch({
    this.supportItemCode,
    this.supportItemName,
  });

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

  Map<String, dynamic> toJson() => {
        'price_tier_override': priceTierOverride,
      };
}

class VisitTaskBillingPatch {
  const VisitTaskBillingPatch({required this.billableMinutes});

  final int billableMinutes;

  Map<String, dynamic> toJson() => {
        'billable_minutes': billableMinutes,
      };
}

/// PATCH body for visit task NDIS code (`null` clears).
class VisitTaskSupportItemPatch {
  const VisitTaskSupportItemPatch({this.supportItemCode});

  final String? supportItemCode;

  Map<String, dynamic> toJson() => {
        'support_item_code': supportItemCode,
      };
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
          .map((e) => NdisCatalogueItemOut.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
    );
  }
}

class InvoiceExportCreateRequest {
  const InvoiceExportCreateRequest({required this.visitIds});

  final List<String> visitIds;

  Map<String, dynamic> toJson() => {
        'visit_ids': visitIds,
      };
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
      finalizedAt: json['finalized_at'] != null
          ? DateTime.tryParse(json['finalized_at'].toString())
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      lines: (json['lines'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => InvoiceExportLineOut.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
    );
  }
}
