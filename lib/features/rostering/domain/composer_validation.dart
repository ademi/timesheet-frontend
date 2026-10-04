import '../../shifts/data/models/shift_models.dart';
import '../../shifts/data/models/shift_travel_models.dart';
import '../../shifts/utils/allocation_math.dart';
import 'composer_steps.dart';
import 'occurrence_draft.dart';
import 'travel_shares_validation.dart';

/// Client-side gates before save / publish / step advance.
abstract final class ComposerValidation {
  ComposerValidation._();

  static const maxParticipants = 32;

  static const placeRequired = 'Add a place';
  static const participantsRequired = 'Add a client';
  static const participantsCap = 'Groups are limited to 32 participants';
  static const oneSessionSingleClient = 'One session allows only one client';
  static const supportAnchorRequired = 'Add a support item before publishing';
  static const supportAnchorStep = 'Choose a support item';
  static const scheduleRequired = 'Set start and end times';
  static const scheduleOrder = 'End must be after start';
  static const otherAddressRequired = 'Enter and look up the other address';
  static const otherAddressConfirm = 'Confirm the looked-up address';
  static const allocationRequired =
      'Enter allocation % for each client (must sum to 100)';
  static const allocationSum =
      'Custom allocation percentages must sum to 100';

  /// Returns human-readable errors (empty when valid).
  ///
  /// Gates: place required, N≤32, publish needs support anchor when
  /// no auto-seed. Schedule order is checked when both ends are set.
  static List<String> validate(
    OccurrenceDraft draft, {
    bool forPublish = false,
    bool hasAutoSeedSupport = false,
  }) {
    final errors = <String>[];

    if (draft.participantIds.isEmpty) {
      errors.add(participantsRequired);
    } else if (draft.preset == ComposerPreset.oneSession &&
        draft.participantIds.length > 1) {
      errors.add(oneSessionSingleClient);
    }

    if (draft.place == null) {
      errors.add(placeRequired);
    }

    if (draft.participantIds.length > maxParticipants) {
      errors.add(participantsCap);
    }

    final start = draft.scheduledStart;
    final end = draft.scheduledEnd;
    if (start == null || end == null) {
      errors.add(scheduleRequired);
    } else if (!end.isAfter(start)) {
      errors.add(scheduleOrder);
    }

    if (forPublish && !hasAutoSeedSupport && !draft.hasSupportAnchor) {
      errors.add(supportAnchorRequired);
    }

    return errors;
  }

  /// Per-step gate before Next (does not require full draft completeness).
  static List<String> validateStep(
    ComposerStep step,
    OccurrenceDraft draft, {
    String? travelError,
    String? allocationError,
    bool otherPlaceNeedsLookup = false,
    bool otherPlaceNeedsConfirm = false,
  }) {
    switch (step) {
      case ComposerStep.clients:
        final errors = <String>[];
        if (draft.participantIds.isEmpty) {
          errors.add(participantsRequired);
        }
        if (draft.preset == ComposerPreset.oneSession &&
            draft.participantIds.length > 1) {
          errors.add(oneSessionSingleClient);
        }
        if (draft.participantIds.length > maxParticipants) {
          errors.add(participantsCap);
        }
        if (allocationError != null && allocationError.isNotEmpty) {
          errors.add(allocationError);
        }
        return errors;
      case ComposerStep.when:
        final start = draft.scheduledStart;
        final end = draft.scheduledEnd;
        if (start == null || end == null) return [scheduleRequired];
        if (!end.isAfter(start)) return [scheduleOrder];
        return const [];
      case ComposerStep.place:
        if (draft.place == null) return [placeRequired];
        if (otherPlaceNeedsLookup) return [otherAddressRequired];
        if (otherPlaceNeedsConfirm) return [otherAddressConfirm];
        if (travelError != null && travelError.isNotEmpty) {
          return [travelError];
        }
        return const [];
      case ComposerStep.support:
        if (!draft.hasSupportAnchor) return [supportAnchorStep];
        return const [];
      case ComposerStep.forms:
      case ComposerStep.workers:
        return const [];
    }
  }

  /// Labour travel share checks for the Place step (empty minutes = OK).
  static String? validateTravel({
    required String labourMinutes,
    required TravelApportionmentMode mode,
    String? nominatedClientId,
    Map<String, String> explicitShares = const {},
  }) {
    final minutes = labourMinutes.trim();
    if (minutes.isEmpty) return null;
    if (mode == TravelApportionmentMode.nominated &&
        (nominatedClientId == null || nominatedClientId.isEmpty)) {
      return 'Choose a nominated participant';
    }
    if (mode == TravelApportionmentMode.explicit) {
      return TravelSharesValidation.explicitSumMismatch(
        journeyMinutes: minutes,
        shareMinutesByParticipant: explicitShares,
      );
    }
    final parsed = double.tryParse(minutes);
    if (parsed == null || !parsed.isFinite || parsed <= 0) {
      return 'Travel minutes must be greater than 0';
    }
    return null;
  }

  static bool isIncompleteLabelledPlace(ShiftPlaceIn? place) {
    if (place is! ShiftPlaceLabelled) return false;
    return place.label.trim().isEmpty || place.postalCode.trim().isEmpty;
  }

  /// Custom percentage allocations when equal_split is off.
  static String? validateCustomAllocation({
    required OccurrenceDraft draft,
    required Map<String, double> percentByParticipant,
  }) {
    if (draft.preset != ComposerPreset.group || draft.equalSplit) {
      return null;
    }
    final ids = draft.participantIds;
    if (ids.isEmpty) return null;
    final values = <double>[];
    for (final id in ids) {
      final value = percentByParticipant[id];
      if (value == null || !value.isFinite || value <= 0) {
        return allocationRequired;
      }
      values.add(value);
    }
    if (!sumsTo100(values)) return allocationSum;
    return null;
  }
}
