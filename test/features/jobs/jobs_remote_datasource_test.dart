import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/constants/api_paths.dart';
import 'package:rostiq/features/billing/data/models/billing_models.dart';
import 'package:rostiq/features/jobs/data/datasources/jobs_remote_datasource.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late JobsRemoteDataSource dataSource;

  const clientId = 'client-1';
  final jobJson = {
    'id': 'job-1',
    'tenant_id': 'tenant-1',
    'client_id': clientId,
    'kind': 'standing',
    'status': 'open',
    'title': 'Sam Lee support',
    'geofence_radius_m': 100,
    'geofence_mode': 'informational',
    'created_at': '2026-08-15T09:00:00Z',
    'updated_at': '2026-08-15T09:00:00Z',
  };

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: '/'));
  });

  setUp(() {
    dio = MockDio();
    dataSource = JobsRemoteDataSource(authenticatedDio: dio);
  });

  test('getOngoingSupport calls client ongoing-support path', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        ApiPaths.clientOngoingSupport(clientId),
      ),
    ).thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(
          path: ApiPaths.clientOngoingSupport(clientId),
        ),
        data: jobJson,
      ),
    );

    final job = await dataSource.getOngoingSupport(clientId);

    expect(job.id, 'job-1');
    expect(job.clientId, clientId);
    verify(
      () => dio.get<Map<String, dynamic>>(
        ApiPaths.clientOngoingSupport(clientId),
      ),
    ).called(1);
  });

  test('ensureOngoingSupport posts to ensure path with optional title', () async {
    when(
      () => dio.post<Map<String, dynamic>>(
        ApiPaths.clientOngoingSupportEnsure(clientId),
        data: any(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(
          path: ApiPaths.clientOngoingSupportEnsure(clientId),
        ),
        data: jobJson,
      ),
    );

    final job = await dataSource.ensureOngoingSupport(
      clientId,
      title: '  Custom title  ',
    );

    expect(job.title, 'Sam Lee support');
    verify(
      () => dio.post<Map<String, dynamic>>(
        ApiPaths.clientOngoingSupportEnsure(clientId),
        data: {'title': 'Custom title'},
      ),
    ).called(1);
  });

  test('ensureOngoingSupport omits title when blank', () async {
    when(
      () => dio.post<Map<String, dynamic>>(
        ApiPaths.clientOngoingSupportEnsure(clientId),
        data: any(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(
          path: ApiPaths.clientOngoingSupportEnsure(clientId),
        ),
        data: jobJson,
      ),
    );

    await dataSource.ensureOngoingSupport(clientId);

    verify(
      () => dio.post<Map<String, dynamic>>(
        ApiPaths.clientOngoingSupportEnsure(clientId),
        data: const <String, dynamic>{},
      ),
    ).called(1);
  });

  test('patchJobSupportItem patches job support item path', () async {
    when(
      () => dio.patch<Map<String, dynamic>>(
        ApiPaths.jobSupportItem('job-1'),
        data: any(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: ApiPaths.jobSupportItem('job-1')),
        data: {
          ...jobJson,
          'support_item_code': '01_011_0107_1_1',
          'support_item_name': 'Self care',
        },
      ),
    );

    final job = await dataSource.patchJobSupportItem(
      'job-1',
      const SupportItemPatch(
        supportItemCode: '01_011_0107_1_1',
        supportItemName: 'Self care',
      ),
    );

    expect(job.supportItemCode, '01_011_0107_1_1');
  });
}
