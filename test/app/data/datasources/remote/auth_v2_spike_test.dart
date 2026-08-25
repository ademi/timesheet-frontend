import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/data/datasources/remote/auth_remote_datasource.dart';
import 'package:rostiq/app/data/models/auth/switch_tenant_request_model.dart';

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

  test('switchTenant posts tenant_id and parses new tokens + engagements', () async {
    const request = SwitchTenantRequestModel(
      tenantId: '22222222-2222-2222-2222-222222222222',
    );
    when(
      () => authenticatedDio.post<Map<String, dynamic>>(
        '/v1/auth/switch-tenant',
        data: request.toJson(),
      ),
    ).thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/v1/auth/switch-tenant'),
        statusCode: 200,
        data: {
          'access_token': 'new-access',
          'refresh_token': 'new-refresh',
          'token_type': 'bearer',
          'actor_type': 'contractor',
          'engagements': [
            {
              'id': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
              'tenant_id': '22222222-2222-2222-2222-222222222222',
              'tenant_name': 'Acme Care',
              'status': 'active',
            },
          ],
        },
      ),
    );

    final result = await dataSource.switchTenant(request);

    expect(result.accessToken, 'new-access');
    expect(result.refreshToken, 'new-refresh');
    expect(result.actorType, 'contractor');
    expect(result.engagements.single.tenantName, 'Acme Care');
  });

  test('getMeContext hits /v1/auth/me/context', () async {
    when(
      () => authenticatedDio.get<Map<String, dynamic>>('/v1/auth/me/context'),
    ).thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/v1/auth/me/context'),
        statusCode: 200,
        data: {
          'actor_type': 'tenant_member',
          'tenant_id': '22222222-2222-2222-2222-222222222222',
          'contractor_id': null,
          'tenant_member_id': '44444444-4444-4444-4444-444444444444',
          'timezone': 'Australia/Sydney',
          'engagements': <Map<String, dynamic>>[],
        },
      ),
    );

    final result = await dataSource.getMeContext();

    expect(result.actorType, 'tenant_member');
    expect(result.tenantMemberId, isNotNull);
    expect(result.timezone, 'Australia/Sydney');
    expect(result.engagements, isEmpty);
  });
}
