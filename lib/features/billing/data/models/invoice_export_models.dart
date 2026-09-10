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
    this.participantNdisNumber,
    this.clientName,
    this.priceTier,
    this.visitTaskId,
    this.shiftParticipantId,
  });

  final String id;
  final String visitId;
  final String? clientId;
  final String? participantNdisNumber;
  final String supportItemNumber;
  final String supportItemName;
  final DateTime serviceDate;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double lineAmount;
  final String? clientName;
  final String? priceTier;
  final String? visitTaskId;
  final String? shiftParticipantId;

  factory InvoiceExportLineOut.fromJson(Map<String, dynamic> json) {
    return InvoiceExportLineOut(
      id: json['id'].toString(),
      visitId: json['visit_id'].toString(),
      clientId: json['client_id']?.toString(),
      participantNdisNumber: json['participant_ndis_number']?.toString(),
      supportItemNumber: json['support_item_number'] as String? ?? '',
      supportItemName: json['support_item_name'] as String? ?? '',
      serviceDate: DateTime.parse(json['service_date'].toString()),
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      unit: json['unit'] as String? ?? '',
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
      lineAmount: (json['line_amount'] as num?)?.toDouble() ?? 0,
      clientName: json['client_name'] as String?,
      priceTier: json['price_tier'] as String?,
      visitTaskId: json['visit_task_id']?.toString(),
      shiftParticipantId: json['shift_participant_id']?.toString(),
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

  bool get isVoided => status == 'void' || status == 'voided';

  factory InvoiceExportOut.fromJson(Map<String, dynamic> json) {
    final linesRaw = json['lines'];
    return InvoiceExportOut(
      id: json['id'].toString(),
      tenantId: json['tenant_id'].toString(),
      status: json['status'] as String? ?? '',
      lineCount: (json['line_count'] as num?)?.toInt() ?? 0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      currencyCode: json['currency_code'] as String? ?? 'AUD',
      catalogueReleaseId: json['catalogue_release_id']?.toString(),
      createdByUserId: json['created_by_user_id']?.toString(),
      finalizedAt: json['finalized_at'] == null
          ? null
          : DateTime.tryParse(json['finalized_at'].toString()),
      createdAt: DateTime.parse(json['created_at'].toString()),
      updatedAt: DateTime.parse(json['updated_at'].toString()),
      lines: linesRaw is List
          ? linesRaw
              .whereType<Map>()
              .map(
                (line) => InvoiceExportLineOut.fromJson(
                  Map<String, dynamic>.from(line),
                ),
              )
              .toList(growable: false)
          : const [],
    );
  }
}

class InvoiceExportCreateRequest {
  const InvoiceExportCreateRequest({required this.visitIds});

  final List<String> visitIds;

  Map<String, dynamic> toJson() => {'visit_ids': visitIds};
}
