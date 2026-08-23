import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:rostiq/core/network/auth_interceptor.dart';
import 'package:rostiq/core/services/token_storage.dart';

/// Returns 401 for authenticated calls; refresh endpoint also fails.
class _FailingAdapter implements HttpClientAdapter {
  _FailingAdapter({this.refreshStatus = 401});

  final int refreshStatus;
  int meCalls = 0;
  int refreshCalls = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.contains('/v1/auth/refresh')) {
      refreshCalls++;
      return ResponseBody.fromString(
        '{"detail":"invalid"}',
        refreshStatus,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    meCalls++;
    return ResponseBody.fromString(
      '{"detail":"unauthorized"}',
      401,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TokenStorage storage;
  late Dio plainDio;
  late Dio authenticatedDio;
  late _FailingAdapter adapter;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    Get.reset();
    Get.testMode = true;

    storage = TokenStorage();
    await storage.loadFromStorage();
    await storage.persistTokens(
      accessToken: 'expired-access',
      refreshToken: 'bad-refresh',
    );

    adapter = _FailingAdapter();
    plainDio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
    authenticatedDio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
    plainDio.httpClientAdapter = adapter;
    authenticatedDio.httpClientAdapter = adapter;

    authenticatedDio.interceptors.add(
      AuthInterceptor(
        storage: storage,
        plainDio: plainDio,
        authenticatedDio: authenticatedDio,
      ),
    );
  });

  tearDown(Get.reset);

  test('401 with failed refresh clears tokens', () async {
    expect(storage.accessToken, 'expired-access');
    expect(storage.refreshToken, 'bad-refresh');

    await expectLater(
      () => authenticatedDio.get('/v1/me'),
      throwsA(isA<DioException>()),
    );

    expect(adapter.refreshCalls, greaterThanOrEqualTo(1));
    expect(storage.accessToken, isNull);
    expect(storage.refreshToken, isNull);
  });

  test('401 with missing refresh token clears tokens', () async {
    await storage.clear();
    await storage.persistTokens(
      accessToken: 'expired-access',
      refreshToken: '',
    );

    await expectLater(
      () => authenticatedDio.get('/v1/me'),
      throwsA(isA<DioException>()),
    );

    expect(storage.accessToken, isNull);
  });
}
