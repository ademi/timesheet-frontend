import '../datasources/billing_remote_datasource.dart';
import '../models/billing_models.dart';

class BillingRepository {
  BillingRepository({required BillingRemoteDataSource remote}) : _remote = remote;

  final BillingRemoteDataSource _remote;

  Future<List<InvoiceExportOut>> listInvoiceExports({int limit = 100}) =>
      _remote.listInvoiceExports(limit: limit);

  Future<InvoiceExportOut> createInvoiceExport(
    InvoiceExportCreateRequest body,
  ) =>
      _remote.createInvoiceExport(body);

  Future<InvoiceExportOut> getInvoiceExport(String exportId) =>
      _remote.getInvoiceExport(exportId);

  Future<String> downloadInvoiceExportCsv(String exportId) =>
      _remote.downloadInvoiceExportCsv(exportId);

  Future<InvoiceExportOut> voidInvoiceExport(String exportId) =>
      _remote.voidInvoiceExport(exportId);
}
