import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/constants/api_paths.dart';
import 'package:rostiq/features/billing/data/datasources/ndis_catalogue_remote_datasource.dart';
import 'package:rostiq/features/billing/data/repositories/ndis_catalogue_repository.dart';

class MockDio extends Mock implements Dio {}

Map<String, dynamic> _cataloguePayload({required int itemCount, int limit = 2000}) {
  return {
    'q': '',
    'limit': limit,
    'items': [
      for (var i = 0; i < itemCount; i++)
        {
          'support_item_number': '01_01${i}_0107_1_1',
          'support_item_name': 'Item $i',
          'support_category_number': '01',
          'support_category_name': 'Assistance with Daily Life',
          'registration_group_number': '0107',
          'registration_group_name': 'Daily Personal Activities',
        },
    ],
  };
}

void main() {
  late MockDio dio;
  late NdisCatalogueRepository repository;
  var getCalls = 0;

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: '/'));
  });

  setUp(() {
    dio = MockDio();
    getCalls = 0;
    repository = NdisCatalogueRepository(
      remote: NdisCatalogueRemoteDataSource(authenticatedDio: dio),
    );

    when(
      () => dio.get<Map<String, dynamic>>(
        ApiPaths.ndisCatalogueItems,
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer((_) async {
      getCalls += 1;
      return Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: ApiPaths.ndisCatalogueItems),
        data: _cataloguePayload(itemCount: 3),
      );
    });
  });

  test('fetchAllActiveItems hits network once then serves cache', () async {
    final first = await repository.fetchAllActiveItems();
    final second = await repository.fetchAllActiveItems();

    expect(first, hasLength(3));
    expect(second, hasLength(3));
    expect(first.first.supportItemNumber, '01_010_0107_1_1');
    expect(
      second.map((i) => i.supportItemNumber),
      first.map((i) => i.supportItemNumber),
    );
    expect(getCalls, 1);
    verify(
      () => dio.get<Map<String, dynamic>>(
        ApiPaths.ndisCatalogueItems,
        queryParameters: {'q': '', 'limit': 2000},
      ),
    ).called(1);
  });

  test('fetchAllActiveItems default limit is 2000', () async {
    await repository.fetchAllActiveItems();

    verify(
      () => dio.get<Map<String, dynamic>>(
        ApiPaths.ndisCatalogueItems,
        queryParameters: {'q': '', 'limit': 2000},
      ),
    ).called(1);
  });

  test('clearCache forces a second network fetch', () async {
    await repository.fetchAllActiveItems();
    repository.clearCache();
    final afterClear = await repository.fetchAllActiveItems();

    expect(afterClear, hasLength(3));
    expect(getCalls, 2);
    verify(
      () => dio.get<Map<String, dynamic>>(
        ApiPaths.ndisCatalogueItems,
        queryParameters: {'q': '', 'limit': 2000},
      ),
    ).called(2);
  });
}
