import '../datasources/contractor_me_remote_datasource.dart';
import '../models/contractor_me_models.dart';

class ContractorMeRepository {
  ContractorMeRepository({required ContractorMeRemoteDataSource remote})
    : _remote = remote;

  final ContractorMeRemoteDataSource _remote;

  Future<ContractorMeOut> getMe() => _remote.getMe();

  Future<ContractorMeOut> patchMe({
    String? fullName,
    String? phone,
    String? dob,
    String? abn,
  }) => _remote.patchMe(
    fullName: fullName,
    phone: phone,
    dob: dob,
    abn: abn,
  );

  Future<ContractorMeOut> putPaymentDetails(ContractorPaymentDetailsIn body) =>
      _remote.putPaymentDetails(body);

  Future<ContractorMeOut> deletePaymentDetails() =>
      _remote.deletePaymentDetails();
}
