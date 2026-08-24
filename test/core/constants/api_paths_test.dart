import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/core/constants/api_paths.dart';

void main() {
  group('ApiPaths NDIS billing', () {
    test('catalogue search path', () {
      expect(ApiPaths.ndisCatalogueItems, '/v1/ndis-catalogue/items');
    });

    test('invoice export paths', () {
      expect(ApiPaths.invoiceExports, '/v1/billing/invoice-exports');
      const id = '00000000-0000-4000-8000-000000000001';
      expect(ApiPaths.invoiceExport(id),
          '/v1/billing/invoice-exports/$id');
      expect(ApiPaths.invoiceExportCsv(id),
          '/v1/billing/invoice-exports/$id/csv');
      expect(ApiPaths.invoiceExportVoid(id),
          '/v1/billing/invoice-exports/$id/void');
    });

    test('support item and billing patch paths', () {
      const jobId = 'job-1';
      const visitId = 'visit-1';
      const taskId = 'task-1';
      expect(ApiPaths.jobSupportItem(jobId), '/v1/jobs/$jobId/support-item');
      expect(ApiPaths.visitSupportItem(visitId),
          '/v1/visits/$visitId/support-item');
      expect(ApiPaths.visitPriceTier(visitId), '/v1/visits/$visitId/price-tier');
      expect(
        ApiPaths.visitTaskBilling(visitId, taskId),
        '/v1/visits/$visitId/tasks/$taskId/billing',
      );
    });
  });
}
