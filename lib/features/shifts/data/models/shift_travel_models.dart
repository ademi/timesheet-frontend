enum TravelApportionmentMode {
  equal('equal'),
  nominated('nominated');

  const TravelApportionmentMode(this.apiValue);

  final String apiValue;

  static TravelApportionmentMode fromJson(Object? value) {
    return values.firstWhere(
      (mode) => mode.apiValue == value,
      orElse: () => TravelApportionmentMode.equal,
    );
  }
}

enum TravelClaimKind {
  nonLabour('non_labour'),
  labour('labour');

  const TravelClaimKind(this.apiValue);

  final String apiValue;

  static TravelClaimKind fromJson(Object? value) {
    return values.firstWhere(
      (kind) => kind.apiValue == value,
      orElse: () => TravelClaimKind.nonLabour,
    );
  }
}

class ShiftTravelOut {
  const ShiftTravelOut({
    required this.id,
    required this.shiftId,
    required this.quantity,
    required this.apportionmentMode,
    required this.createdAt,
    required this.updatedAt,
    this.claimKind = TravelClaimKind.nonLabour,
    this.supportItemCode,
    this.nominatedParticipantId,
    this.claimedExportId,
    this.notes,
    this.mmmCategory,
    this.mmmCapMinutes,
    this.overCap,
  });

  final String id;
  final String shiftId;
  final TravelClaimKind claimKind;
  final String? supportItemCode;
  final double quantity;
  final TravelApportionmentMode apportionmentMode;
  final String? nominatedParticipantId;
  final String? claimedExportId;
  final String? notes;
  final int? mmmCategory;
  final int? mmmCapMinutes;
  final bool? overCap;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isClaimed => claimedExportId != null;
  bool get isLabour => claimKind == TravelClaimKind.labour;

  factory ShiftTravelOut.fromJson(Map<String, dynamic> json) {
    return ShiftTravelOut(
      id: json['id'].toString(),
      shiftId: json['shift_id'].toString(),
      claimKind: TravelClaimKind.fromJson(json['claim_kind']),
      supportItemCode: json['support_item_code'] as String?,
      quantity:
          json['quantity'] is num
              ? (json['quantity'] as num).toDouble()
              : double.parse(json['quantity'].toString()),
      apportionmentMode: TravelApportionmentMode.fromJson(
        json['apportionment_mode'],
      ),
      nominatedParticipantId: json['nominated_participant_id']?.toString(),
      claimedExportId: json['claimed_export_id']?.toString(),
      notes: json['notes'] as String?,
      mmmCategory: json['mmm_category'] as int?,
      mmmCapMinutes: json['mmm_cap_minutes'] as int?,
      overCap: json['over_cap'] as bool?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

/// Shared create and full-update body for a travel claim.
class ShiftTravelWrite {
  const ShiftTravelWrite({
    required this.apportionmentMode,
    this.claimKind = TravelClaimKind.nonLabour,
    this.supportItemCode,
    this.quantity,
    this.quantityMinutes,
    this.nominatedParticipantId,
    this.notes,
  });

  final TravelClaimKind claimKind;
  final String? supportItemCode;
  final String? quantity;
  final String? quantityMinutes;
  final TravelApportionmentMode apportionmentMode;
  final String? nominatedParticipantId;
  final String? notes;

  Map<String, dynamic> toJson() {
    if (claimKind == TravelClaimKind.labour) {
      return {
        'claim_kind': claimKind.apiValue,
        'quantity_minutes': quantityMinutes,
        'apportionment_mode': apportionmentMode.apiValue,
        'nominated_participant_id': nominatedParticipantId,
        if (notes != null) 'notes': notes,
      };
    }
    return {
      'claim_kind': claimKind.apiValue,
      'support_item_code': supportItemCode,
      'quantity': quantity,
      'apportionment_mode': apportionmentMode.apiValue,
      'nominated_participant_id': nominatedParticipantId,
      if (notes != null) 'notes': notes,
    };
  }
}
