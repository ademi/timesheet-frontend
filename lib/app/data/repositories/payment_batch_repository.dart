import '../../../core/services/token_storage.dart';
import '../datasources/remote/payment_batch_remote_datasource.dart';

/// DOMAIN_V2 repository stub for PaymentBatch (Phase 2 � implement in Phase 3).
class PaymentBatchRepository {
  PaymentBatchRepository({
    required PaymentBatchRemoteDataSource remote,
    required TokenStorage tokenStorage,
  })  : _remote = remote,
        _tokenStorage = tokenStorage;

  // ignore: unused_field
  final PaymentBatchRemoteDataSource _remote;
  // ignore: unused_field
  final TokenStorage _tokenStorage;
}
