import '../datasources/payroll_remote_datasource.dart';
import '../models/payroll_models.dart';

class PayrollRepository {
  PayrollRepository({required PayrollRemoteDataSource remote}) : _remote = remote;

  final PayrollRemoteDataSource _remote;

  Future<List<EngagementRateOut>> listRates(String engagementId) =>
      _remote.listRates(engagementId);

  Future<EngagementRateOut> createRate(
    String engagementId,
    EngagementRateCreateRequest body,
  ) =>
      _remote.createRate(engagementId, body);

  Future<EngagementRateOut> patchRate(
    String rateId, {
    String? effectiveTo,
    RateBands? bands,
  }) =>
      _remote.patchRate(rateId, effectiveTo: effectiveTo, bands: bands);

  Future<List<PaymentBatchOut>> listBatches({String? status}) =>
      _remote.listBatches(status: status);

  Future<PaymentBatchOut> createBatch(
    PaymentBatchCreateRequest body, {
    required String idempotencyKey,
  }) =>
      _remote.createBatch(body, idempotencyKey: idempotencyKey);

  Future<PaymentBatchOut> postBatch(String id) => _remote.postBatch(id);

  Future<PaymentBatchOut> voidBatch(String id) => _remote.voidBatch(id);

  Future<TenantSettingsOut> getTenant(String tenantId) =>
      _remote.getTenant(tenantId);

  Future<TenantSettingsOut> patchTenant(
    String tenantId, {
    String? timezone,
    String? publicHolidayJurisdiction,
  }) =>
      _remote.patchTenant(
        tenantId,
        timezone: timezone,
        publicHolidayJurisdiction: publicHolidayJurisdiction,
      );
}
