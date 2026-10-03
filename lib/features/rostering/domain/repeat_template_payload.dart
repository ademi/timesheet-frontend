import '../../jobs/data/models/job_models.dart';
import '../../jobs/utils/recurrence_rrule_builder.dart';
import '../../jobs/utils/time_window_utils.dart';
import '../../shifts/data/models/shift_models.dart';
import '../data/composer_models.dart';
import 'occurrence_draft.dart';

/// Builds A7 recurrence create/patch bodies from the occurrence draft.
class RepeatTemplatePayload {
  const RepeatTemplatePayload._();

  static String hhmm(DateTime civil) =>
      '${civil.hour.toString().padLeft(2, '0')}:'
      '${civil.minute.toString().padLeft(2, '0')}';

  static RecurrencePlaceIn? placeFromDraft(ShiftPlaceIn? place) {
    if (place == null) return null;
    return switch (place) {
      ShiftPlaceBranch(:final branchId) => RecurrencePlaceIn.branch(branchId),
      ShiftPlaceClientSite(:final clientSiteId) =>
        RecurrencePlaceIn.clientSite(clientSiteId),
      ShiftPlaceLabelled(
        :final label,
        :final latitude,
        :final longitude,
        :final postalCode,
        :final geofenceRadiusM,
      ) =>
        RecurrencePlaceIn.labelled(
          label: label,
          latitude: latitude,
          longitude: longitude,
          postalCode: postalCode,
          geofenceRadiusM: geofenceRadiusM,
        ),
    };
  }

  static List<RecurrenceParticipantIn> participantsFromDraft(
    OccurrenceDraft draft,
  ) {
    return [
      for (final id in draft.participantIds)
        RecurrenceParticipantIn(participantId: id),
    ];
  }

  static List<RecurrenceFormOverrideIn> formOverridesFrom(
    List<ShiftFormOverrideOut> overrides,
  ) {
    return [
      for (final o in overrides)
        RecurrenceFormOverrideIn(
          formTemplateId: o.formTemplateId,
          action: o.action,
          isRequired: o.isRequired,
        ),
    ];
  }

  static List<RecurrenceSegmentTemplateIn> segmentsFromDraft(
    OccurrenceDraft draft,
  ) {
    return [
      for (final s in draft.segmentTemplate)
        RecurrenceSegmentTemplateIn(
          participantId: s.participantId,
          anchorSupportItemCode: s.anchorSupportItemCode,
          kind: s.kind,
          offsetStartMinutes: s.offsetStartMinutes,
          offsetEndMinutes: s.offsetEndMinutes,
          groupSize: s.groupSize,
          notes: s.notes,
          sortOrder: s.sortOrder,
        ),
    ];
  }

  static TimeWindow? windowFromSchedule(OccurrenceDraft draft) {
    final start = draft.scheduledStart;
    final end = draft.scheduledEnd;
    if (start == null || end == null) return null;
    return TimeWindow(startTime: hhmm(start), endTime: hhmm(end));
  }

  static RecurrenceRuleCreateRequest buildCreate({
    required OccurrenceDraft draft,
    required RecurrenceFrequency frequency,
    required Set<int> weekdays,
    required DateTime startDate,
    required DateTime endDate,
    required String publishPolicy,
    required List<String> preferredContractorIds,
    required List<ShiftFormOverrideOut> formOverrides,
  }) {
    final window = windowFromSchedule(draft);
    if (window == null) {
      throw StateError('scheduled start/end required for repeat template');
    }
    return RecurrenceRuleCreateRequest(
      contractorIds: preferredContractorIds,
      requiredSlots: draft.requiredSlots,
      workerCount: draft.workerCount,
      publishPolicy: publishPolicy,
      rrule: compileRecurrenceRrule(
        frequency: frequency,
        weekdays: weekdays,
      ),
      dtstart: DateTime(startDate.year, startDate.month, startDate.day),
      until: recurrenceUntilInstant(endDate),
      timeWindows: [window],
      taskTemplate: draft.taskTemplate,
      place: placeFromDraft(draft.place),
      participants: participantsFromDraft(draft),
      formOverrides: formOverridesFrom(formOverrides),
      segmentTemplate: segmentsFromDraft(draft),
    );
  }

  static RecurrenceRulePatchRequest buildPatch({
    required OccurrenceDraft draft,
    required String publishPolicy,
    required List<String> preferredContractorIds,
    required List<ShiftFormOverrideOut> formOverrides,
    List<TimeWindow>? timeWindows,
  }) {
    return RecurrenceRulePatchRequest(
      requiredSlots: draft.requiredSlots,
      workerCount: draft.workerCount,
      publishPolicy: publishPolicy,
      timeWindows: timeWindows,
      taskTemplate: draft.taskTemplate,
      place: placeFromDraft(draft.place),
      participants: participantsFromDraft(draft),
      formOverrides: formOverridesFrom(formOverrides),
      segmentTemplate: segmentsFromDraft(draft),
      contractorIds: preferredContractorIds,
    );
  }
}
