import '../../../core/services/token_storage.dart';
import '../datasources/remote/form_remote_datasource.dart';

/// DOMAIN_V2 repository stub for Form (Phase 2 � implement in Phase 3).
class FormRepository {
  FormRepository({
    required FormRemoteDataSource remote,
    required TokenStorage tokenStorage,
  })  : _remote = remote,
        _tokenStorage = tokenStorage;

  // ignore: unused_field
  final FormRemoteDataSource _remote;
  // ignore: unused_field
  final TokenStorage _tokenStorage;
}
