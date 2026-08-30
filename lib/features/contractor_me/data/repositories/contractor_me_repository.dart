import '../../../contractor_register/data/models/contractor_register_models.dart';
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
    String? addressLine1,
    String? addressLine2,
    String? suburb,
    String? state,
    String? postcode,
    String? country,
    Map<String, dynamic>? metadata,
  }) => _remote.patchMe(
    fullName: fullName,
    phone: phone,
    dob: dob,
    abn: abn,
    addressLine1: addressLine1,
    addressLine2: addressLine2,
    suburb: suburb,
    state: state,
    postcode: postcode,
    country: country,
    metadata: metadata,
  );

  Future<GeocodeResponse> geocode(GeocodeRequest body) => _remote.geocode(body);

  Future<ContractorMeOut> putPaymentDetails(ContractorPaymentDetailsIn body) =>
      _remote.putPaymentDetails(body);

  Future<ContractorMeOut> deletePaymentDetails() =>
      _remote.deletePaymentDetails();
}
