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

class ShiftTravelOut {
  const ShiftTravelOut({
    required this.id,
    required this.shiftId,
    required this.supportItemCode,
    required this.quantity,
    required this.apportionmentMode,
    required this.createdAt,
    required this.updatedAt,
    this.nominatedParticipantId,
    this.claimedExportId,
    this.notes,
  });

  final String id;
  final String shiftId;
  final String supportItemCode;
  final double quantity;
  final TravelApportionmentMode apportionmentMode;
  final String? nominatedParticipantId;
  final String? claimedExportId;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isClaimed => claimedExportId != null;

  factory ShiftTravelOut.fromJson(Map<String, dynamic> json) {
    return ShiftTravelOut(
      id: json['id'].toString(),
      shiftId: json['shift_id'].toString(),
      supportItemCode: json['support_item_code'] as String,
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
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

/// Shared create and full-update body for a travel claim.
class ShiftTravelWrite {
  const ShiftTravelWrite({
    required this.supportItemCode,
    required this.quantity,
    required this.apportionmentMode,
    this.nominatedParticipantId,
    this.notes,
  });

  final String supportItemCode;
  final String quantity;
  final TravelApportionmentMode apportionmentMode;
  final String? nominatedParticipantId;
  final String? notes;

  Map<String, dynamic> toJson() => {
    'support_item_code': supportItemCode,
    'quantity': quantity,
    'apportionment_mode': apportionmentMode.apiValue,
    'nominated_participant_id': nominatedParticipantId,
    if (notes != null) 'notes': notes,
  };
}
