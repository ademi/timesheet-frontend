import '../data/models/shift_travel_models.dart';

/// Immutable state and validation for the Item · Split · Review wizard.
class TravelDraft {
  const TravelDraft({
    this.supportItemCode,
    this.supportItemName,
    this.quantity,
    this.notes,
    this.apportionmentMode = TravelApportionmentMode.equal,
    this.nominatedParticipantId,
  });

  final String? supportItemCode;
  final String? supportItemName;
  final String? quantity;
  final String? notes;
  final TravelApportionmentMode apportionmentMode;
  final String? nominatedParticipantId;

  TravelDraft copyWith({
    String? supportItemCode,
    String? supportItemName,
    String? quantity,
    String? notes,
    TravelApportionmentMode? apportionmentMode,
    String? nominatedParticipantId,
    bool clearSupportItem = false,
    bool clearQuantity = false,
    bool clearNotes = false,
    bool clearNominee = false,
  }) {
    return TravelDraft(
      supportItemCode:
          clearSupportItem ? null : (supportItemCode ?? this.supportItemCode),
      supportItemName:
          clearSupportItem ? null : (supportItemName ?? this.supportItemName),
      quantity: clearQuantity ? null : (quantity ?? this.quantity),
      notes: clearNotes ? null : (notes ?? this.notes),
      apportionmentMode: apportionmentMode ?? this.apportionmentMode,
      nominatedParticipantId:
          clearNominee
              ? null
              : (nominatedParticipantId ?? this.nominatedParticipantId),
    );
  }

  String? validateItem() {
    if ((supportItemCode?.trim() ?? '').isEmpty) {
      return 'Choose a travel support item';
    }
    final rawQuantity = quantity?.trim() ?? '';
    final parsedQuantity = double.tryParse(rawQuantity);
    if (parsedQuantity == null ||
        !parsedQuantity.isFinite ||
        parsedQuantity <= 0) {
      return 'Travel quantity must be greater than 0';
    }
    final decimalPlaces =
        rawQuantity.contains('.') ? rawQuantity.split('.').last.length : 0;
    if (decimalPlaces > 4) {
      return 'Travel quantity must have at most 4 decimal places';
    }
    if ((notes?.length ?? 0) > 500) {
      return 'Notes must be 500 characters or fewer';
    }
    return null;
  }

  String? validateSplit() {
    if (apportionmentMode == TravelApportionmentMode.equal) {
      if (nominatedParticipantId != null) {
        return 'Equal split cannot have a nominated participant';
      }
      return null;
    }
    if ((nominatedParticipantId?.trim() ?? '').isEmpty) {
      return 'Choose a nominated participant';
    }
    return null;
  }

  String? validateReview(List<String> activeParticipantIds) {
    if (activeParticipantIds.isEmpty) {
      return 'Add participants before claiming travel';
    }
    if (apportionmentMode == TravelApportionmentMode.nominated &&
        !activeParticipantIds.contains(nominatedParticipantId)) {
      return 'The nominated participant is no longer active';
    }
    return null;
  }

  String? validateAll(List<String> activeParticipantIds) =>
      validateItem() ?? validateSplit() ?? validateReview(activeParticipantIds);

  ShiftTravelWrite toWrite() {
    return ShiftTravelWrite(
      supportItemCode: supportItemCode!.trim(),
      quantity: quantity!.trim(),
      apportionmentMode: apportionmentMode,
      nominatedParticipantId:
          apportionmentMode == TravelApportionmentMode.nominated
              ? nominatedParticipantId
              : null,
      notes: (notes?.trim().isEmpty ?? true) ? null : notes!.trim(),
    );
  }
}
