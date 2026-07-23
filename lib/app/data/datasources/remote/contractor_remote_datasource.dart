import 'package:dio/dio.dart';

/// DOMAIN_V2 remote datasource stub for Contractor (Phase 2 � implement in Phase 3).
///
/// Controllers must not call Dio; go through [ContractorRepository].
class ContractorRemoteDataSource {
  ContractorRemoteDataSource({required Dio dio}) : _dio = dio;

  // ignore: unused_field
  final Dio _dio;
}
