import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/constants/api_paths.dart';
import 'package:rostiq/features/billing/data/datasources/ndis_catalogue_remote_datasource.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late NdisCatalogueRemoteDataSource dataSource;

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: '/'));
  });

  setUp(() {
    dio = MockDio();
    dataSource = NdisCatalogueRemoteDataSource(authenticatedDio: dio);
  });

  test('searchItems calls catalogue path with query', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        ApiPaths.ndisCatalogueItems,
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: ApiPaths.ndisCatalogueItems),
        data: {
          'q': 'self care',
          'limit': 10,
          'items': [
            {
              'support_item_number': '01_011_0107_1_1',
              'support_item_name': 'Self care',
            },
          ],
        },
      ),
    );

    final result = await dataSource.searchItems(q: '  self care  ', limit: 10);

    expect(result.items.single.supportItemNumber, '01_011_0107_1_1');
    verify(
      () => dio.get<Map<String, dynamic>>(
        ApiPaths.ndisCatalogueItems,
        queryParameters: {'q': 'self care', 'limit': 10},
      ),
    ).called(1);
  });
}
