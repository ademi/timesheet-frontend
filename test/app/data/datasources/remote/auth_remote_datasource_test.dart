import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/data/datasources/remote/auth_remote_datasource.dart';
import 'package:rostiq/app/data/models/auth/login_request_model.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio plainDio;
  late MockDio authenticatedDio;
  late AuthRemoteDataSource dataSource;

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: '/'));
  });

  setUp(() {
    plainDio = MockDio();
    authenticatedDio = MockDio();
    dataSource = AuthRemoteDataSource(
      plainDio: plainDio,
      authenticatedDio: authenticatedDio,
    );
  });

  test('login uses plain dio client', () async {
    const request = LoginRequestModel(
      identifier: 'admin@example.com',
      password: 'secret',
    );
    when(
      () => plainDio.post<Map<String, dynamic>>(
        '/v1/auth/login',
        data: request.toJson(),
      ),
    ).thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/v1/auth/login'),
        statusCode: 200,
        data: {
          'access_token': 'access',
          'refresh_token': 'refresh',
          'token_type': 'bearer',
        },
      ),
    );

    final result = await dataSource.login(request);

    expect(result.accessToken, 'access');
    expect(result.refreshToken, 'refresh');
    verify(
      () => plainDio.post<Map<String, dynamic>>(
        '/v1/auth/login',
        data: request.toJson(),
      ),
    ).called(1);
    verifyNever(
      () => authenticatedDio.post<Map<String, dynamic>>(
        '/v1/auth/login',
        data: any(named: 'data'),
      ),
    );
  });
}
