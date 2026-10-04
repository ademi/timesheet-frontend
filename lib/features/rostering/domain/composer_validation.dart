import 'composer_steps.dart';
import 'occurrence_draft.dart';

/// Client-side gates before save / publish / step advance.
abstract final class ComposerValidation {
  ComposerValidation._();

  static const maxParticipants = 32;

  static const placeRequired = 'Add a place';
  static const participantsRequired = 'Add a client';
  static const participantsCap = 'Groups are limited to 32 participants';
  static const supportAnchorRequired = 'Add a support item before publishing';
  static const scheduleRequired = 'Set start and end times';
  static const scheduleOrder = 'End must be after start';

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
  static List<String> validateStep(ComposerStep step, OccurrenceDraft draft) {
    switch (step) {
      case ComposerStep.clients:
        final errors = <String>[];
        if (draft.participantIds.isEmpty) {
          errors.add(participantsRequired);
        }
        if (draft.participantIds.length > maxParticipants) {
          errors.add(participantsCap);
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
        return const [];
      case ComposerStep.support:
      case ComposerStep.forms:
      case ComposerStep.workers:
        return const [];
    }
  }
}
