import 'package:dio/dio.dart';

import '../../../../core/constants/api_paths.dart';
import '../../../../core/errors/app_failure.dart';
import '../models/import_models.dart';

class ImportsRemoteDataSource {
  ImportsRemoteDataSource({required Dio authenticatedDio})
    : _dio = authenticatedDio;

  final Dio _dio;

  Future<ImportReportOut> previewParticipants(String csv) =>
      _post(ApiPaths.importsParticipantsPreview, csv);

  Future<ImportReportOut> commitParticipants(String csv) =>
      _post(ApiPaths.importsParticipantsCommit, csv);

  Future<ImportReportOut> previewWorkers(String csv) =>
      _post(ApiPaths.importsWorkersPreview, csv);

  Future<ImportReportOut> commitWorkers(String csv) =>
      _post(ApiPaths.importsWorkersCommit, csv);

  Future<ImportReportOut> _post(String path, String csv) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: ImportCsvRequest(csv: csv).toJson(),
      );
      final data = response.data;
      if (data == null) {
        throw const AppFailure(
          code: 'unknown',
          message: 'Empty import response',
          presentation: AppFailurePresentation.toast,
        );
      }
      return ImportReportOut.fromJson(data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }
}
