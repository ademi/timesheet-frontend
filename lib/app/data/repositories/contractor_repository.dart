import '../../../core/services/token_storage.dart';
import '../datasources/remote/contractor_remote_datasource.dart';

/// DOMAIN_V2 repository stub for Contractor (Phase 2 � implement in Phase 3).
class ContractorRepository {
  ContractorRepository({
    required ContractorRemoteDataSource remote,
    required TokenStorage tokenStorage,
  })  : _remote = remote,
        _tokenStorage = tokenStorage;

  // ignore: unused_field
  final ContractorRemoteDataSource _remote;
  // ignore: unused_field
  final TokenStorage _tokenStorage;
}
