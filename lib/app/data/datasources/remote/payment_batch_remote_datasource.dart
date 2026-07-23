import 'package:dio/dio.dart';

/// DOMAIN_V2 remote datasource stub for PaymentBatch (Phase 2 � implement in Phase 3).
///
/// Controllers must not call Dio; go through [PaymentBatchRepository].
class PaymentBatchRemoteDataSource {
  PaymentBatchRemoteDataSource({required Dio dio}) : _dio = dio;

  // ignore: unused_field
  final Dio _dio;
}
