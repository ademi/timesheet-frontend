import '../../../core/services/token_storage.dart';
import '../datasources/remote/engagement_remote_datasource.dart';

/// DOMAIN_V2 repository stub for Engagement (Phase 2 � implement in Phase 3).
class EngagementRepository {
  EngagementRepository({
    required EngagementRemoteDataSource remote,
    required TokenStorage tokenStorage,
  })  : _remote = remote,
        _tokenStorage = tokenStorage;

  // ignore: unused_field
  final EngagementRemoteDataSource _remote;
  // ignore: unused_field
  final TokenStorage _tokenStorage;
}
