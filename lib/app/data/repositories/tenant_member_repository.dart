import '../../../core/services/token_storage.dart';
import '../datasources/remote/tenant_member_remote_datasource.dart';

/// DOMAIN_V2 repository stub for TenantMember (Phase 2 � implement in Phase 3).
class TenantMemberRepository {
  TenantMemberRepository({
    required TenantMemberRemoteDataSource remote,
    required TokenStorage tokenStorage,
  })  : _remote = remote,
        _tokenStorage = tokenStorage;

  // ignore: unused_field
  final TenantMemberRemoteDataSource _remote;
  // ignore: unused_field
  final TokenStorage _tokenStorage;
}
