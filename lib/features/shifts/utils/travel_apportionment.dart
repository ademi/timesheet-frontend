import '../data/models/shift_travel_models.dart';

const int travelQuantityScale = 10000;

/// Mirrors the backend's 4dp ROUND_DOWN + largest-remainder apportionment.
///
/// Arithmetic is performed in integer 0.0001 units so shares always total the
/// rounded input quantity without floating-point remainder drift.
Map<String, double> apportionTravelQuantity({
  required TravelApportionmentMode mode,
  required double totalQty,
  required List<String> participantIds,
  String? nominatedParticipantId,
}) {
  if (!totalQty.isFinite || totalQty <= 0) {
    throw ArgumentError.value(totalQty, 'totalQty', 'must be positive');
  }
  if (participantIds.isEmpty) {
    throw ArgumentError.value(
      participantIds,
      'participantIds',
      'must not be empty',
    );
  }

  final totalUnits = (totalQty * travelQuantityScale).round();
  if (mode == TravelApportionmentMode.nominated) {
    if (nominatedParticipantId == null ||
        !participantIds.contains(nominatedParticipantId)) {
      throw ArgumentError.value(
        nominatedParticipantId,
        'nominatedParticipantId',
        'must be an active participant',
      );
    }
    return {nominatedParticipantId: totalUnits / travelQuantityScale};
  }

  final baseUnits = totalUnits ~/ participantIds.length;
  var residualUnits = totalUnits - (baseUnits * participantIds.length);
  final shares = <String, double>{};
  for (final participantId in participantIds) {
    final units = baseUnits + (residualUnits > 0 ? 1 : 0);
    if (residualUnits > 0) residualUnits -= 1;
    shares[participantId] = units / travelQuantityScale;
  }
  return shares;
}
