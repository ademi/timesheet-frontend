import '../datasources/imports_remote_datasource.dart';
import '../models/import_models.dart';

class ImportsRepository {
  ImportsRepository({required ImportsRemoteDataSource remote})
    : _remote = remote;

  final ImportsRemoteDataSource _remote;

  Future<ImportReportOut> preview(ImportKind kind, String csv) =>
      switch (kind) {
        ImportKind.participants => _remote.previewParticipants(csv),
        ImportKind.workers => _remote.previewWorkers(csv),
      };

  Future<ImportReportOut> commit(ImportKind kind, String csv) =>
      switch (kind) {
        ImportKind.participants => _remote.commitParticipants(csv),
        ImportKind.workers => _remote.commitWorkers(csv),
      };
}
