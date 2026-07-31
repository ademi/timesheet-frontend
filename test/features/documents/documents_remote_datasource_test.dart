import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/constants/api_paths.dart';
import 'package:rostiq/core/errors/app_failure.dart';
import 'package:rostiq/features/documents/data/datasources/documents_remote_datasource.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late DocumentsRemoteDataSource dataSource;

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: '/'));
  });

  setUp(() {
    dio = MockDio();
    dataSource = DocumentsRemoteDataSource(authenticatedDio: dio);
  });

  test('listDocuments sends owner_type and owner_id query params', () async {
    when(
      () => dio.get<List<dynamic>>(
        ApiPaths.documents,
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer(
      (_) async => Response<List<dynamic>>(
        requestOptions: RequestOptions(path: ApiPaths.documents),
        data: const [],
      ),
    );

    await dataSource.listDocuments(
      ownerType: 'contractor',
      ownerId: 'contractor-1',
    );

    verify(
      () => dio.get<List<dynamic>>(
        ApiPaths.documents,
        queryParameters: {
          'owner_type': 'contractor',
          'owner_id': 'contractor-1',
          'limit': 100,
        },
      ),
    ).called(1);
  });

  test('listDocuments rejects empty owner params before network call', () async {
    await expectLater(
      dataSource.listDocuments(ownerType: '', ownerId: 'id'),
      throwsA(isA<AppFailure>()),
    );
    verifyNever(
      () => dio.get<List<dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    );
  });
}
