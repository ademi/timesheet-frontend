import '../datasources/billing_remote_datasource.dart';
import '../models/invoice_export_models.dart';

class BillingRepository {
  BillingRepository({required BillingRemoteDataSource remote})
      : _remote = remote;

  final BillingRemoteDataSource _remote;

  Future<List<InvoiceExportOut>> listExports({int limit = 100}) =>
      _remote.listExports(limit: limit);

  Future<InvoiceExportOut> getExport(String id) => _remote.getExport(id);

  Future<InvoiceExportOut> createExport(InvoiceExportCreateRequest body) =>
      _remote.createExport(body);

  Future<InvoiceExportOut> voidExport(String id) => _remote.voidExport(id);

  Future<String> downloadCsv(String id) => _remote.downloadCsv(id);
}
