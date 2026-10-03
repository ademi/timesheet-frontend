import 'occurrence_draft.dart';

/// Client-side gates before save / publish (composer Stage A).
abstract final class ComposerValidation {
  ComposerValidation._();

  static const maxParticipants = 32;

  static const placeRequired = 'Add a place';
  static const participantsCap = 'Groups are limited to 32 participants';
  static const supportAnchorRequired = 'Add a support item before publishing';
  static const scheduleOrder = 'End must be after start';

  /// Returns human-readable errors (empty when valid).
  ///
  /// Gates for Task 2: place required, N≤32, publish needs support anchor when
  /// no auto-seed. Schedule order is checked when both ends are set.
  static List<String> validate(
    OccurrenceDraft draft, {
    bool forPublish = false,
    bool hasAutoSeedSupport = false,
  }) {
    final errors = <String>[];

    if (draft.place == null) {
      errors.add(placeRequired);
    }

    if (draft.participantIds.length > maxParticipants) {
      errors.add(participantsCap);
    }

    final start = draft.scheduledStart;
    final end = draft.scheduledEnd;
    if (start != null && end != null && !end.isAfter(start)) {
      errors.add(scheduleOrder);
    }

    if (forPublish && !hasAutoSeedSupport && !draft.hasSupportAnchor) {
      errors.add(supportAnchorRequired);
    }

    return errors;
  }
}
