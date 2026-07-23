import '../../../core/services/token_storage.dart';
import '../datasources/remote/job_remote_datasource.dart';

/// DOMAIN_V2 repository stub for Job (Phase 2 � implement in Phase 3).
class JobRepository {
  JobRepository({
    required JobRemoteDataSource remote,
    required TokenStorage tokenStorage,
  })  : _remote = remote,
        _tokenStorage = tokenStorage;

  // ignore: unused_field
  final JobRemoteDataSource _remote;
  // ignore: unused_field
  final TokenStorage _tokenStorage;
}
