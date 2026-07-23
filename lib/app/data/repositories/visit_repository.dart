import '../../../core/services/token_storage.dart';
import '../datasources/remote/visit_remote_datasource.dart';

class VisitRepository {
  VisitRepository({
    required VisitRemoteDataSource remote,
    required TokenStorage tokenStorage,
  })  : _remote = remote,
        _tokenStorage = tokenStorage;

  final VisitRemoteDataSource _remote;
  // ignore: unused_field
  final TokenStorage _tokenStorage;

  VisitRemoteDataSource get remote => _remote;
}
