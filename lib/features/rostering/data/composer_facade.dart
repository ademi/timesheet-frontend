import '../../jobs/data/models/job_models.dart';
import '../../jobs/data/repositories/jobs_repository.dart';
import '../../shifts/data/models/shift_models.dart';
import '../../shifts/data/models/shift_travel_models.dart';
import '../../shifts/data/repositories/shifts_repository.dart';
import 'composer_models.dart';

/// Thin composer I/O seam over [ShiftsRepository] (+ recurrence via [JobsRepository]).
///
/// Controllers should depend on this facade / repositories — never Dio.
class ComposerFacade {
  ComposerFacade({
    required ShiftsRepository shifts,
    JobsRepository? jobs,
  }) : _shifts = shifts,
       _jobs = jobs;

  final ShiftsRepository _shifts;
  final JobsRepository? _jobs;

  ShiftsRepository get shifts => _shifts;

  JobsRepository get jobs {
    final repo = _jobs;
    if (repo == null) {
      throw StateError('JobsRepository was not provided to ComposerFacade');
    }
    return repo;
  }

  /// First save only — `POST /v1/shifts`.
  Future<ShiftOut> createShift(ShiftCreateRequest body) =>
      _shifts.createShift(body);

  /// Subsequent draft plan saves — expanded `PATCH /v1/shifts/{id}`.
  Future<ShiftOut> patchDraftShift(String shiftId, ShiftPatchRequest body) =>
      _shifts.patchDraftShift(shiftId, body);

  Future<ComposerShiftOut> getComposer(String shiftId) =>
      _shifts.getComposer(shiftId);

  Future<List<ResolvedFormPreviewOut>> previewForms(
    FormPreviewRequirementsRequest body,
  ) => _shifts.previewForms(body);

  Future<ComposerShiftOut> copyShift(
    String shiftId,
    ShiftCopyRequest body,
  ) => _shifts.copyShift(shiftId, body);

  Future<AssignContextOut> fetchAssignContext({
    required DateTime from,
    required DateTime to,
    String? clientId,
  }) => _shifts.fetchAssignContext(from: from, to: to, clientId: clientId);

  Future<PlaceOptionsOut> fetchPlaceOptions({
    List<String> participantIds = const [],
  }) => _shifts.fetchPlaceOptions(participantIds: participantIds);

  Future<List<ShiftFormOverrideOut>> listFormOverrides(String shiftId) =>
      _shifts.listFormOverrides(shiftId);

  Future<List<ShiftFormOverrideOut>> putFormOverrides(
    String shiftId,
    List<ShiftFormOverrideOut> overrides,
  ) => _shifts.putFormOverrides(shiftId, overrides);

  Future<List<SupportSegmentOut>> listVisitSegments(
    String shiftId,
    String visitId,
  ) => _shifts.listVisitSegments(shiftId, visitId);

  Future<List<SupportSegmentOut>> putVisitSegments(
    String shiftId,
    String visitId,
    List<SupportSegmentIn> segments,
  ) => _shifts.putVisitSegments(shiftId, visitId, segments);

  Future<List<ShiftTravelOut>> listTravel(String shiftId) =>
      _shifts.listTravel(shiftId);

  Future<ShiftTravelOut> createTravel(String shiftId, ShiftTravelWrite body) =>
      _shifts.createTravel(shiftId, body);

  Future<ShiftTravelOut> updateTravel(
    String shiftId,
    String travelId,
    ShiftTravelWrite body,
  ) => _shifts.updateTravel(shiftId, travelId, body);

  Future<void> deleteTravel(String shiftId, String travelId) =>
      _shifts.deleteTravel(shiftId, travelId);

  Future<ShiftOut> putParticipants(
    String shiftId,
    ShiftParticipantsReplaceRequest body,
  ) => _shifts.putParticipants(shiftId, body);

  Future<ShiftOut> assignShift({
    required String shiftId,
    required String contractorId,
    List<TaskTemplateItem>? taskTemplate,
    String? reason,
  }) => _shifts.assignShift(
    shiftId: shiftId,
    contractorId: contractorId,
    taskTemplate: taskTemplate,
    reason: reason,
  );

  Future<ShiftOut> assignShiftBatch({
    required String shiftId,
    required List<String> contractorIds,
    List<TaskTemplateItem>? taskTemplate,
    String? reason,
  }) => _shifts.assignShiftBatch(
    shiftId: shiftId,
    contractorIds: contractorIds,
    taskTemplate: taskTemplate,
    reason: reason,
  );

  Future<ShiftOut> publishShift(String id, {ShiftPublishRequest? body}) =>
      _shifts.publishShift(id, body: body);

  Future<RecurrenceRuleOut> createRecurrenceRule(
    String jobId,
    RecurrenceRuleCreateRequest body,
  ) => jobs.createRecurrenceRule(jobId, body);

  Future<RecurrenceRuleOut> patchRecurrenceRule({
    required String jobId,
    required String ruleId,
    required bool isActive,
  }) => jobs.patchRecurrenceRule(
    jobId: jobId,
    ruleId: ruleId,
    isActive: isActive,
  );

  Future<GenerateVisitsResponse> generateVisits({
    required String jobId,
    required String ruleId,
    required GenerateVisitsRequest body,
    required String idempotencyKey,
  }) => jobs.generateVisits(
    jobId: jobId,
    ruleId: ruleId,
    body: body,
    idempotencyKey: idempotencyKey,
  );

  Future<SplitRecurrenceOut> splitRecurrenceFrom({
    required String jobId,
    required String ruleId,
    required SplitRecurrenceRequest body,
  }) => jobs.splitRecurrenceFrom(jobId: jobId, ruleId: ruleId, body: body);
}
