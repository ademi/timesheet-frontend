import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/constants/api_paths.dart';
import 'package:rostiq/features/billing/data/datasources/billing_remote_datasource.dart';
import 'package:rostiq/features/billing/data/models/billing_models.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late BillingRemoteDataSource dataSource;

  const exportId = 'export-1';
  final exportJson = {
    'id': exportId,
    'tenant_id': 'tenant-1',
    'status': 'finalized',
    'line_count': 0,
    'total_amount': 0,
    'currency_code': 'AUD',
    'created_at': '2026-01-15T10:00:00Z',
    'updated_at': '2026-01-15T10:00:00Z',
    'lines': <Map<String, dynamic>>[],
  };

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: '/'));
    registerFallbackValue(Options());
  });

  setUp(() {
    dio = MockDio();
    dataSource = BillingRemoteDataSource(authenticatedDio: dio);
  });

  test('listInvoiceExports calls billing list path', () async {
    when(
      () => dio.get<List<dynamic>>(
        ApiPaths.invoiceExports,
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer(
      (_) async => Response<List<dynamic>>(
        requestOptions: RequestOptions(path: ApiPaths.invoiceExports),
        data: [exportJson],
      ),
    );

    final exports = await dataSource.listInvoiceExports(limit: 50);

    expect(exports.single.id, exportId);
    verify(
      () => dio.get<List<dynamic>>(
        ApiPaths.invoiceExports,
        queryParameters: {'limit': 50},
      ),
    ).called(1);
  });

  test('createInvoiceExport posts visit ids', () async {
    when(
      () => dio.post<Map<String, dynamic>>(
        ApiPaths.invoiceExports,
        data: any(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: ApiPaths.invoiceExports),
        data: exportJson,
      ),
    );

    await dataSource.createInvoiceExport(
      const InvoiceExportCreateRequest(visitIds: ['visit-1']),
    );

    verify(
      () => dio.post<Map<String, dynamic>>(
        ApiPaths.invoiceExports,
        data: {'visit_ids': ['visit-1']},
      ),
    ).called(1);
  });

  test('downloadInvoiceExportCsv uses plain response type', () async {
    when(
      () => dio.get<String>(
        ApiPaths.invoiceExportCsv(exportId),
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => Response<String>(
        requestOptions: RequestOptions(path: ApiPaths.invoiceExportCsv(exportId)),
        data: 'participant_ndis_number,service_date\n',
      ),
    );

    final csv = await dataSource.downloadInvoiceExportCsv(exportId);

    expect(csv, contains('participant_ndis_number'));
    verify(
      () => dio.get<String>(
        ApiPaths.invoiceExportCsv(exportId),
        options: any(
          named: 'options',
          that: predicate<Options>(
            (o) => o.responseType == ResponseType.plain,
          ),
        ),
      ),
    ).called(1);
  });

  test('voidInvoiceExport posts void path', () async {
    when(
      () => dio.post<Map<String, dynamic>>(
        ApiPaths.invoiceExportVoid(exportId),
      ),
    ).thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(
          path: ApiPaths.invoiceExportVoid(exportId),
        ),
        data: {...exportJson, 'status': 'void'},
      ),
    );

    final result = await dataSource.voidInvoiceExport(exportId);

    expect(result.isVoid, isTrue);
  });
}
