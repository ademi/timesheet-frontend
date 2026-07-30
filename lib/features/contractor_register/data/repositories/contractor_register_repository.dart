import '../datasources/contractor_register_remote_datasource.dart';
import '../models/contractor_register_models.dart';

class ContractorRegisterRepository {
  ContractorRegisterRepository({
    required ContractorRegisterRemoteDataSource remote,
  }) : _remote = remote;

  final ContractorRegisterRemoteDataSource _remote;

  Future<ContractorInvitePublicOut> getPublicInvite(String token) =>
      _remote.getPublicInvite(token);

  Future<ContractorRegisterResponse> register(
    ContractorRegisterRequest request,
  ) => _remote.register(request);
}
