import 'package:dio/dio.dart';

/// DOMAIN_V2 remote datasource stub for Client (Phase 2 � implement in Phase 3).
///
/// Controllers must not call Dio; go through [ClientRepository].
class ClientRemoteDataSource {
  ClientRemoteDataSource({required Dio dio}) : _dio = dio;

  // ignore: unused_field
  final Dio _dio;
}
