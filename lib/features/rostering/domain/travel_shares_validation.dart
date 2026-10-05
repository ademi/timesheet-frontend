/// Client-side labour travel share checks (mirrors BE `travel_shares_sum_mismatch`).
class TravelSharesValidation {
  const TravelSharesValidation._();

  /// Returns an error when explicit share minutes do not sum to [journeyMinutes].
  ///
  /// Empty [shareMinutesByParticipant] is treated as incomplete, not a match.
  static String? explicitSumMismatch({
    required String? journeyMinutes,
    required Map<String, String> shareMinutesByParticipant,
  }) {
    final journey = _parsePositiveMinutes(journeyMinutes);
    if (journey == null) {
      return 'Travel minutes must be greater than 0';
    }
    if (shareMinutesByParticipant.isEmpty) {
      return 'Add a share for each participant';
    }

    var sum = 0.0;
    for (final raw in shareMinutesByParticipant.values) {
      final minutes = _parsePositiveMinutes(raw);
      if (minutes == null) {
        return 'Each share must be greater than 0';
      }
      sum += minutes;
    }

    // Compare at 4dp like the API quantity_minutes scale.
    final journeyRounded = (journey * 10000).round();
    final sumRounded = (sum * 10000).round();
    if (journeyRounded != sumRounded) {
      return 'Share minutes must sum to travel minutes';
    }
    return null;
  }

  static double? _parsePositiveMinutes(String? raw) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    final parsed = double.tryParse(trimmed);
    if (parsed == null || !parsed.isFinite || parsed <= 0) return null;
    final decimalPlaces =
        trimmed.contains('.') ? trimmed.split('.').last.length : 0;
    if (decimalPlaces > 4) return null;
    return parsed;
  }
}
