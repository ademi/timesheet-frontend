import 'package:dio/dio.dart';

import '../../models/visit/visit_check_in_out.dart';
import '../../models/visit/visit_gps_body.dart';

/// Minimal visit remote calls for Phase 1 check-in spike.
class VisitRemoteDataSource {
  VisitRemoteDataSource({required Dio authenticatedDio})
      : _authenticatedDio = authenticatedDio;

  final Dio _authenticatedDio;

  Future<VisitCheckInOut> checkIn({
    required String visitId,
    required VisitGpsBody gps,
    String? idempotencyKey,
  }) async {
    final response = await _authenticatedDio.post<Map<String, dynamic>>(
      '/v1/visits/$visitId/check-in',
      data: gps.toJson(),
      options: Options(
        headers: {
          if (idempotencyKey != null && idempotencyKey.isNotEmpty)
            'Idempotency-Key': idempotencyKey,
        },
      ),
    );
    final data = response.data;
    if (data == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        message: 'Empty check-in response',
      );
    }
    return VisitCheckInOut.fromJson(data);
  }
}
