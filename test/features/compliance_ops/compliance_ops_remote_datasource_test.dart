import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/constants/api_paths.dart';
import 'package:rostiq/features/compliance_ops/data/datasources/compliance_ops_remote_datasource.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late ComplianceOpsRemoteDataSource dataSource;

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: '/'));
  });

  setUp(() {
    dio = MockDio();
    dataSource = ComplianceOpsRemoteDataSource(authenticatedDio: dio);
  });

  test('listAccessHistory uses compliance path and credential_id query', () async {
    when(
      () => dio.get<dynamic>(
        ApiPaths.accessHistory,
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer(
      (_) async => Response<dynamic>(
        requestOptions: RequestOptions(path: ApiPaths.accessHistory),
        data: const [],
      ),
    );

    await dataSource.listAccessHistory(credentialId: 'cred-1');

    verify(
      () => dio.get<dynamic>(
        ApiPaths.accessHistory,
        queryParameters: {
          'credential_id': 'cred-1',
          'limit': 100,
        },
      ),
    ).called(1);
    expect(ApiPaths.accessHistory, '/v1/compliance/access-history');
  });
}
