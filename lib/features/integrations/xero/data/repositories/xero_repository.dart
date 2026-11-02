import '../datasources/xero_remote_datasource.dart';
import '../models/xero_models.dart';

class XeroRepository {
  XeroRepository({required XeroRemoteDataSource remote}) : _remote = remote;

  final XeroRemoteDataSource _remote;

  Future<XeroConnectionStatus> getStatus() => _remote.getStatus();

  Future<XeroAuthUrlOut> getAuthUrl() => _remote.getAuthUrl();

  Future<XeroDisconnectOut> disconnect() => _remote.disconnect();

  Future<List<XeroEmployee>> listEmployees() => _remote.listEmployees();

  Future<List<XeroEarningsRate>> listEarningsRates() =>
      _remote.listEarningsRates();

  Future<XeroEmployeeMappingsOut> getEmployeeMappings() =>
      _remote.getEmployeeMappings();

  Future<XeroEmployeeMappingsOut> putEmployeeMappings(
    XeroEmployeeMappingsOut body,
  ) => _remote.putEmployeeMappings(body);

  Future<XeroPayItemMappingsOut> getPayItemMappings() =>
      _remote.getPayItemMappings();

  Future<XeroPayItemMappingsOut> putPayItemMappings(
    XeroPayItemMappingsOut body,
  ) => _remote.putPayItemMappings(body);

  Future<XeroExportResult> exportPaymentBatch(
    String batchId, {
    required String idempotencyKey,
  }) => _remote.exportPaymentBatch(batchId, idempotencyKey: idempotencyKey);
}
