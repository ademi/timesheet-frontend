import '../datasources/billing_remote_datasource.dart';
import '../models/billing_models.dart';

class BillingRepository {
  BillingRepository({required BillingRemoteDataSource remote})
    : _remote = remote;

  final BillingRemoteDataSource _remote;

  Future<List<InvoiceExportOut>> listInvoiceExports({int limit = 100}) =>
      _remote.listInvoiceExports(limit: limit);

  Future<InvoiceExportOut> createInvoiceExport(
    InvoiceExportCreateRequest body,
  ) => _remote.createInvoiceExport(body);

  Future<InvoiceExportOut> getInvoiceExport(String exportId) =>
      _remote.getInvoiceExport(exportId);

  Future<String> downloadInvoiceExportCsv(String exportId) =>
      _remote.downloadInvoiceExportCsv(exportId);

  Future<InvoiceExportOut> voidInvoiceExport(String exportId) =>
      _remote.voidInvoiceExport(exportId);

  Future<List<UnclaimedAgeingVisitOut>> listUnclaimedAgeing({
    String? clientId,
    String? branchId,
    int? minDays,
    bool approaching90 = false,
    int limit = 200,
  }) => _remote.listUnclaimedAgeing(
    clientId: clientId,
    branchId: branchId,
    minDays: minDays,
    approaching90: approaching90,
    limit: limit,
  );

  Future<List<BurnEnvelopeAlertOut>> listBudgetAlerts({
    String? severity,
    int limit = 200,
  }) => _remote.listBudgetAlerts(severity: severity, limit: limit);

  Future<PublishBurnReportOut> previewPublishBurn(String shiftId) =>
      _remote.previewPublishBurn(shiftId);

  Future<List<PaymentEnquiryOut>> listPaymentEnquiries({
    String? clientId,
    String? status,
    int limit = 200,
  }) => _remote.listPaymentEnquiries(
    clientId: clientId,
    status: status,
    limit: limit,
  );

  Future<List<ArAgeingExportOut>> listArAgeing({
    String? managementType,
    int? minDays,
    bool includePaid = false,
    int limit = 200,
  }) => _remote.listArAgeing(
    managementType: managementType,
    minDays: minDays,
    includePaid: includePaid,
    limit: limit,
  );

  Future<ArAgeingExportOut> patchArExport(
    String exportId, {
    String? arPaymentStatus,
    String? delayReason,
    bool clearDelayReason = false,
  }) => _remote.patchArExport(
    exportId,
    arPaymentStatus: arPaymentStatus,
    delayReason: delayReason,
    clearDelayReason: clearDelayReason,
  );
}
