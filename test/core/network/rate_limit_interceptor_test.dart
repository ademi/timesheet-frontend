import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/core/network/rate_limit_interceptor.dart';

void main() {
  test('waits Retry-After then retries once on 429', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    dio.interceptors.add(RateLimitInterceptor(dio: dio));

    var calls = 0;
    dio.httpClientAdapter = _Adapter(
      onFetch: (options) async {
        calls++;
        if (calls == 1) {
          return ResponseBody.fromString(
            jsonEncode({
              'error': 'Too many requests',
              'code': 'rate_limit_exceeded',
              'retry_after': 0,
            }),
            429,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
              'retry-after': ['0'],
            },
          );
        }
        return ResponseBody.fromString(
          '{"ok":true}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      },
    );

    final response = await dio.get<Map<String, dynamic>>('/v1/resource');
    expect(response.statusCode, 200);
    expect(calls, 2);
    expect(response.data?['ok'], true);
  });

  test('does not retry forever on repeated 429', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    dio.interceptors.add(RateLimitInterceptor(dio: dio));

    var calls = 0;
    dio.httpClientAdapter = _Adapter(
      onFetch: (options) async {
        calls++;
        return ResponseBody.fromString(
          '{"message":"Rate limit exceeded","retry_after":0}',
          429,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
            'retry-after': ['0'],
          },
        );
      },
    );

    await expectLater(dio.get('/v1/resource'), throwsA(isA<DioException>()));
    // Original + one retry.
    expect(calls, 2);
  });
}

class _Adapter implements HttpClientAdapter {
  _Adapter({required this.onFetch});

  final Future<ResponseBody> Function(RequestOptions options) onFetch;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return onFetch(options);
  }
}
