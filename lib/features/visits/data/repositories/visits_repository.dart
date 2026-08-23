import '../../../billing/data/models/billing_models.dart';
import '../datasources/visits_remote_datasource.dart';
import '../models/roster_overlay_models.dart';
import '../models/visit_models.dart';

class VisitsRepository {
  VisitsRepository({required VisitsRemoteDataSource remote}) : _remote = remote;

  final VisitsRemoteDataSource _remote;

  Future<List<VisitOut>> listVisits({
    DateTime? from,
    DateTime? to,
    String? jobId,
    String? clientId,
    String? contractorId,
    String? status,
    String? paymentStatus,
    int limit = 100,
  }) =>
      _remote.listVisits(
        from: from,
        to: to,
        jobId: jobId,
        clientId: clientId,
        contractorId: contractorId,
        status: status,
        paymentStatus: paymentStatus,
        limit: limit,
      );

  Future<VisitOut> getVisit(String id) => _remote.getVisit(id);

  Future<VisitOut> reschedule({
    required String id,
    required DateTime scheduledStart,
    required DateTime scheduledEnd,
  }) =>
      _remote.reschedule(
        id: id,
        scheduledStart: scheduledStart,
        scheduledEnd: scheduledEnd,
      );

  Future<void> cancel(String id) => _remote.cancel(id);

  Future<VisitCheckInOut> checkIn({
    required String id,
    required VisitGpsBody body,
    required String idempotencyKey,
  }) =>
      _remote.checkIn(id: id, body: body, idempotencyKey: idempotencyKey);

  Future<VisitCompleteOut> complete({
    required String id,
    required VisitGpsBody body,
    required String idempotencyKey,
  }) =>
      _remote.complete(id: id, body: body, idempotencyKey: idempotencyKey);

  Future<VisitTaskOut> patchTask({
    required String visitId,
    required String taskId,
    required bool isDone,
  }) =>
      _remote.patchTask(visitId: visitId, taskId: taskId, isDone: isDone);

  Future<VisitTaskOut> patchVisitTaskSupportItem({
    required String visitId,
    required String taskId,
    required VisitTaskSupportItemPatch body,
  }) =>
      _remote.patchVisitTaskSupportItem(
        visitId: visitId,
        taskId: taskId,
        body: body,
      );

  Future<VisitOut> patchVisitSupportItem(
    String visitId,
    SupportItemPatch body,
  ) =>
      _remote.patchVisitSupportItem(visitId, body);

  Future<VisitOut> patchVisitPriceTier(
    String visitId,
    VisitPriceTierPatch body,
  ) =>
      _remote.patchVisitPriceTier(visitId, body);

  Future<VisitTaskOut> patchVisitTaskBilling({
    required String visitId,
    required String taskId,
    required VisitTaskBillingPatch body,
  }) =>
      _remote.patchVisitTaskBilling(
        visitId: visitId,
        taskId: taskId,
        body: body,
      );

  Future<void> submitForm({
    required String visitId,
    required VisitFormSubmitRequest body,
  }) =>
      _remote.submitForm(visitId: visitId, body: body);

  Future<List<JobFormCatalogItem>> listJobFormCatalog(String jobId) =>
      _remote.listJobFormCatalog(jobId);

  Future<RosterOverlayOut> fetchRosterOverlay({
    required DateTime from,
    required DateTime to,
  }) =>
      _remote.fetchRosterOverlay(from: from, to: to);
}
