import '../../../core/services/token_storage.dart';
import '../datasources/remote/client_remote_datasource.dart';

/// DOMAIN_V2 repository stub for Client (Phase 2 � implement in Phase 3).
class ClientRepository {
  ClientRepository({
    required ClientRemoteDataSource remote,
    required TokenStorage tokenStorage,
  })  : _remote = remote,
        _tokenStorage = tokenStorage;

  // ignore: unused_field
  final ClientRemoteDataSource _remote;
  // ignore: unused_field
  final TokenStorage _tokenStorage;
}
