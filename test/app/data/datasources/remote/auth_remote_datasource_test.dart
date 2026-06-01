import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yemen_gate_attendance_app/app/data/datasources/remote/auth_remote_datasource.dart';
import 'package:yemen_gate_attendance_app/app/data/models/auth/set_pin_request_model.dart';
import 'package:yemen_gate_attendance_app/app/data/models/auth/verify_pin_request_model.dart';

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

  test('verifyPin uses authenticated dio client', () async {
    const request = VerifyPinRequestModel(employeeId: 'emp-1', pin: '1234');
    when(
      () => authenticatedDio.post<Map<String, dynamic>>(
        '/v1/auth/verify_pin',
        data: request.toJson(),
      ),
    ).thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/v1/auth/verify_pin'),
        statusCode: 200,
        data: {'matched': true, 'pin_not_set': false},
      ),
    );

    final result = await dataSource.verifyPin(request);

    expect(result.matched, isTrue);
    verify(
      () => authenticatedDio.post<Map<String, dynamic>>(
        '/v1/auth/verify_pin',
        data: request.toJson(),
      ),
    ).called(1);
    verifyNever(
      () => plainDio.post<Map<String, dynamic>>(
        '/v1/auth/verify_pin',
        data: any(named: 'data'),
      ),
    );
  });

  test('setPin uses authenticated dio client', () async {
    const request = SetPinRequestModel(
      employeeId: 'emp-1',
      pin: '1234',
      confirmPin: '1234',
    );
    when(
      () => authenticatedDio.post<Map<String, dynamic>>(
        '/v1/auth/set_pin',
        data: request.toJson(),
      ),
    ).thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/v1/auth/set_pin'),
        statusCode: 200,
        data: {'message': 'ok'},
      ),
    );

    final result = await dataSource.setPin(request);

    expect(result, 'ok');
    verify(
      () => authenticatedDio.post<Map<String, dynamic>>(
        '/v1/auth/set_pin',
        data: request.toJson(),
      ),
    ).called(1);
    verifyNever(
      () => plainDio.post<Map<String, dynamic>>(
        '/v1/auth/set_pin',
        data: any(named: 'data'),
      ),
    );
  });
}
