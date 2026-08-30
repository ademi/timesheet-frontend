import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/constants/feature_flags.dart';
import '../../../core/errors/app_failure.dart';
import '../../../features/clients/data/models/client_models.dart' as client_models;
import '../../../features/clients/utils/site_geocode_apply.dart';
import '../../../features/contractor_onboarding/data/onboarding_progress_store.dart';
import '../../../shared/utils/abn_utils.dart';
import '../../../shared/widgets/app_toast.dart';
import '../data/models/contractor_register_models.dart';
import '../data/repositories/contractor_register_repository.dart';

/// Exact `doc_key` values validated by the backend on register.
abstract final class LegalDocKeys {
  static const platformTerms = 'platform_terms';
  static const privacyPolicy = 'privacy_policy';
}

class RegisterQualRow {
  RegisterQualRow({this.type = 'first_aid'});

  String type;
  final issueDateCtrl = TextEditingController();
  final expiryDateCtrl = TextEditingController();

  void dispose() {
    issueDateCtrl.dispose();
    expiryDateCtrl.dispose();
  }
}

class ContractorRegisterController extends GetxController {
  ContractorRegisterController({
    required ContractorRegisterRepository repository,
  }) : _repository = repository;

  final ContractorRegisterRepository _repository;

  static const stepLabels = [
    'Identity',
    'Screening',
    'Qualifications',
    'Checks',
    'Legal',
  ];
  static const maxStep = 4;

  static const qualTypeOptions = <String>[
    'cert_iii',
    'first_aid',
    'cpr',
    'medication_admin',
    'epilepsy_management',
    'manual_handling',
    'nursing_bachelor',
    'other_health_qualification',
  ];

  static const auStates = [
    'NSW',
    'VIC',
    'QLD',
    'WA',
    'SA',
    'TAS',
    'ACT',
    'NT',
  ];

  final step = 0.obs;
  final identityFormKey = GlobalKey<FormState>();

  final fullNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final phoneController = TextEditingController();
  final dobController = TextEditingController();
  final abnController = TextEditingController();
  final accountNameController = TextEditingController();
  final bsbController = TextEditingController();
  final accountNumberController = TextEditingController();

  final addressLine1Controller = TextEditingController();
  final addressLine2Controller = TextEditingController();
  final suburbController = TextEditingController();
  final stateController = TextEditingController();
  final postcodeController = TextEditingController();
  final countryController = TextEditingController(text: 'AU');
  final latController = TextEditingController();
  final lngController = TextEditingController();

  final screeningNumberCtrl = TextEditingController();
  final screeningIssueCtrl = TextEditingController();
  final screeningExpiryCtrl = TextEditingController();
  final screeningStateCtrl = TextEditingController();
  final screeningStatus = RxnString();

  final wwccNumberCtrl = TextEditingController();
  final wwccStateCtrl = TextEditingController();
  final wwccExpiryCtrl = TextEditingController();
  final policeIssueCtrl = TextEditingController();
  final licenceNumberCtrl = TextEditingController();
  final licenceStateCtrl = TextEditingController();
  final licenceExpiryCtrl = TextEditingController();
  final vehiclePlateCtrl = TextEditingController();
  final vehicleStateCtrl = TextEditingController();
  final vehicleExpiryCtrl = TextEditingController();

  final qualifications = <RegisterQualRow>[].obs;

  final isLoading = false.obs;
  final isInviteLoading = false.obs;
  final isGeocoding = false.obs;
  final isPasswordVisible = false.obs;
  final acceptedTerms = false.obs;
  final acceptedPrivacy = false.obs;
  final termsMarkdown = ''.obs;
  final privacyMarkdown = ''.obs;
  final legalLoadError = RxnString();
  final invite = Rxn<ContractorInvitePublicOut>();
  final inviteLoadError = RxnString();
  final errorMessage = RxnString();
  final geocodeFormattedAddress = RxnString();
  final addressConfirmed = false.obs;

  String? _inviteToken;

  String get termsVersion => AppEnv.termsVersion;
  String get privacyVersion => AppEnv.privacyVersion;

  @override
  void onInit() {
    super.onInit();
    stateController.text = auStates.first;
    qualifications.add(RegisterQualRow());
    _loadBundledLegal();
    _loadInviteFromRoute();
  }

  Future<void> _loadInviteFromRoute() async {
    final token = Get.parameters['invite']?.trim();
    if (token == null || token.isEmpty) return;

    _inviteToken = token;
    isInviteLoading.value = true;
    inviteLoadError.value = null;
    try {
      final publicInvite = await _repository.getPublicInvite(token);
      invite.value = publicInvite;
      emailController.text = publicInvite.email;
    } on AppFailure catch (e) {
      inviteLoadError.value = e.message;
    } catch (e) {
      inviteLoadError.value = e.toString();
    } finally {
      isInviteLoading.value = false;
    }
  }

  Future<void> _loadBundledLegal() async {
    try {
      termsMarkdown.value = await rootBundle.loadString(
        'assets/legal/platform_terms.md',
      );
      privacyMarkdown.value = await rootBundle.loadString(
        'assets/legal/privacy_policy.md',
      );
      legalLoadError.value = null;
    } catch (e) {
      legalLoadError.value = 'Could not load legal documents.';
    }
  }

  void togglePasswordVisibility() => isPasswordVisible.toggle();

  void previousStep() {
    if (step.value > 0) step.value--;
  }

  Future<void> nextStep() async {
    errorMessage.value = null;
    if (step.value == 0) {
      if (!(identityFormKey.currentState?.validate() ?? false)) return;
    }
    if (step.value < maxStep) {
      step.value++;
      return;
    }
    await submit();
  }

  void invalidateAddressConfirm() {
    if (!addressConfirmed.value && geocodeFormattedAddress.value == null) {
      return;
    }
    addressConfirmed.value = false;
    geocodeFormattedAddress.value = null;
    latController.clear();
    lngController.clear();
  }

  Future<void> lookupAddress() async {
    addressConfirmed.value = false;
    final line1 = addressLine1Controller.text.trim();
    final city = suburbController.text.trim();
    if (line1.isEmpty || city.isEmpty) {
      errorMessage.value = 'Enter address line 1 and suburb before looking up.';
      return;
    }
    isGeocoding.value = true;
    errorMessage.value = null;
    try {
      final result = await _repository.geocode(
        GeocodeRequest(
          addressLine1: line1,
          city: city,
          country: countryController.text.trim().isEmpty
              ? 'AU'
              : countryController.text.trim(),
          state: stateController.text.trim().isEmpty
              ? null
              : stateController.text.trim(),
        ),
      );
      final outcome = applyGeocodeResponse(
        result: client_models.GeocodeResponse(
          latitude: result.latitude,
          longitude: result.longitude,
          formattedAddress: result.formattedAddress,
          confidence: result.confidence,
        ),
        latCtrl: latController,
        lngCtrl: lngController,
        formattedAddress: geocodeFormattedAddress,
        addressConfirmed: addressConfirmed,
        addressFallback: '$line1, $city',
      );
      if (!outcome.accepted) {
        errorMessage.value = outcome.errorMessage;
      }
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      geocodeFormattedAddress.value = null;
    } catch (e) {
      errorMessage.value = e.toString();
      geocodeFormattedAddress.value = null;
    } finally {
      isGeocoding.value = false;
    }
  }

  void confirmAddress() {
    final lat = double.tryParse(latController.text.trim());
    final lng = double.tryParse(lngController.text.trim());
    if (lat == null || lng == null) {
      errorMessage.value = 'Look up an address before confirming.';
      return;
    }
    addressConfirmed.value = true;
    errorMessage.value = null;
  }

  void editAddressLookup() {
    addressConfirmed.value = false;
    geocodeFormattedAddress.value = null;
    latController.clear();
    lngController.clear();
    errorMessage.value = null;
  }

  void addQualification() => qualifications.add(RegisterQualRow());

  void removeQualification(int index) {
    if (qualifications.length <= 1) return;
    qualifications[index].dispose();
    qualifications.removeAt(index);
  }

  Future<void> pickDob(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25),
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 16),
    );
    if (picked == null) return;
    dobController.text =
        '${picked.year.toString().padLeft(4, '0')}-'
        '${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}';
  }

  Future<void> pickDate(
    BuildContext context,
    TextEditingController controller, {
    DateTime? initial,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 50),
      lastDate: DateTime(now.year + 20),
    );
    if (picked == null) return;
    controller.text =
        '${picked.year.toString().padLeft(4, '0')}-'
        '${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic>? _metadataPayload() {
    final lat = double.tryParse(latController.text.trim());
    final lng = double.tryParse(lngController.text.trim());
    if (lat == null || lng == null) return null;
    return {
      'location': {'latitude': lat, 'longitude': lng},
    };
  }

  Map<String, dynamic>? _compliancePayload() {
    final screening = <String, dynamic>{
      if (screeningNumberCtrl.text.trim().isNotEmpty)
        'number': screeningNumberCtrl.text.trim(),
      if (screeningStatus.value != null) 'status': screeningStatus.value,
      if (screeningIssueCtrl.text.trim().isNotEmpty)
        'issue_date': screeningIssueCtrl.text.trim(),
      if (screeningExpiryCtrl.text.trim().isNotEmpty)
        'expiry_date': screeningExpiryCtrl.text.trim(),
      if (screeningStateCtrl.text.trim().isNotEmpty)
        'state': screeningStateCtrl.text.trim(),
    };
    final quals = <Map<String, dynamic>>[];
    for (final row in qualifications) {
      final item = <String, dynamic>{'type': row.type};
      if (row.issueDateCtrl.text.trim().isNotEmpty) {
        item['issue_date'] = row.issueDateCtrl.text.trim();
      }
      if (row.expiryDateCtrl.text.trim().isNotEmpty) {
        item['expiry_date'] = row.expiryDateCtrl.text.trim();
      }
      if (item.length > 1) quals.add(item);
    }
    final checks = <String, dynamic>{};
    final wwcc = <String, dynamic>{
      if (wwccNumberCtrl.text.trim().isNotEmpty)
        'number': wwccNumberCtrl.text.trim(),
      if (wwccStateCtrl.text.trim().isNotEmpty) 'state': wwccStateCtrl.text.trim(),
      if (wwccExpiryCtrl.text.trim().isNotEmpty)
        'expiry_date': wwccExpiryCtrl.text.trim(),
    };
    if (wwcc.isNotEmpty) checks['wwcc'] = wwcc;
    if (policeIssueCtrl.text.trim().isNotEmpty) {
      checks['police_check'] = {'issue_date': policeIssueCtrl.text.trim()};
    }
    final licence = <String, dynamic>{
      if (licenceNumberCtrl.text.trim().isNotEmpty)
        'number': licenceNumberCtrl.text.trim(),
      if (licenceStateCtrl.text.trim().isNotEmpty)
        'state': licenceStateCtrl.text.trim(),
      if (licenceExpiryCtrl.text.trim().isNotEmpty)
        'expiry_date': licenceExpiryCtrl.text.trim(),
    };
    if (licence.isNotEmpty) checks['drivers_licence'] = licence;
    final vehicle = <String, dynamic>{
      if (vehiclePlateCtrl.text.trim().isNotEmpty)
        'plate': vehiclePlateCtrl.text.trim(),
      if (vehicleStateCtrl.text.trim().isNotEmpty)
        'state': vehicleStateCtrl.text.trim(),
      if (vehicleExpiryCtrl.text.trim().isNotEmpty)
        'expiry_date': vehicleExpiryCtrl.text.trim(),
    };
    if (vehicle.isNotEmpty) checks['vehicle_registration'] = vehicle;

    final payload = <String, dynamic>{};
    if (screening.isNotEmpty) payload['screening'] = screening;
    if (quals.isNotEmpty) payload['qualifications'] = quals;
    if (checks.isNotEmpty) payload['checks'] = checks;
    return payload.isEmpty ? null : payload;
  }

  Future<void> submit() async {
    if (isInviteLoading.value) return;
    if (!(identityFormKey.currentState?.validate() ?? false)) {
      step.value = 0;
      return;
    }
    if (!acceptedTerms.value || !acceptedPrivacy.value) {
      _showError(
        'Accept Platform Terms and Privacy Policy separately to continue.',
      );
      return;
    }
    if (legalLoadError.value != null) {
      _showError(legalLoadError.value!);
      return;
    }

    isLoading.value = true;
    errorMessage.value = null;
    try {
      final phone = phoneController.text.trim();
      final dob = dobController.text.trim();
      String? abn;
      try {
        abn = AbnUtils.normalizeOrNull(abnController.text);
      } on FormatException catch (e) {
        step.value = 0;
        _showError(e.message);
        return;
      }

      ContractorRegisterPaymentDetails? payment;
      final accountName = accountNameController.text.trim();
      final bsb = AbnUtils.digitsOnly(bsbController.text);
      final accountNumber = AbnUtils.digitsOnly(accountNumberController.text);
      final anyPayment =
          accountName.isNotEmpty || bsb.isNotEmpty || accountNumber.isNotEmpty;
      if (anyPayment) {
        if (accountName.isEmpty || bsb.isEmpty || accountNumber.isEmpty) {
          step.value = 0;
          _showError(
            'To save payment details, fill account name, BSB, and account number.',
          );
          return;
        }
        final bsbErr = AbnUtils.bsbValidator(bsb, required: true);
        final acctErr = AbnUtils.accountNumberValidator(
          accountNumber,
          required: true,
        );
        if (bsbErr != null || acctErr != null) {
          step.value = 0;
          _showError(bsbErr ?? acctErr!);
          return;
        }
        payment = ContractorRegisterPaymentDetails(
          accountName: accountName,
          bsb: bsb,
          accountNumber: accountNumber,
        );
      }

      final response = await _repository.register(
        ContractorRegisterRequest(
          fullName: fullNameController.text.trim(),
          email: emailController.text.trim(),
          password: passwordController.text,
          phone: phone.isEmpty ? null : phone,
          dob: dob.isEmpty ? null : dob,
          abn: abn,
          addressLine1: addressLine1Controller.text.trim(),
          addressLine2: addressLine2Controller.text.trim(),
          suburb: suburbController.text.trim(),
          state: stateController.text.trim(),
          postcode: postcodeController.text.trim(),
          country: countryController.text.trim(),
          compliance: _compliancePayload(),
          metadata: _metadataPayload(),
          paymentDetails: payment,
          inviteToken: _inviteToken,
          termsVersion: termsVersion,
          privacyVersion: privacyVersion,
        ),
      );
      await OnboardingProgressStore().markPlatformComplete(response.contractorId);
      AppToast.success(
        'Account created',
        'Sign in with your new contractor account.',
      );
      Get.offAllNamed(AppRoutes.login);
    } on AppFailure catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError(e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  void goToLogin() => Get.offNamed(AppRoutes.login);

  void _showError(String message) {
    errorMessage.value = message;
    AppToast.error('Registration failed', message, duration: const Duration(seconds: 5));
  }

  @override
  void onClose() {
    fullNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    phoneController.dispose();
    dobController.dispose();
    abnController.dispose();
    accountNameController.dispose();
    bsbController.dispose();
    accountNumberController.dispose();
    addressLine1Controller.dispose();
    addressLine2Controller.dispose();
    suburbController.dispose();
    stateController.dispose();
    postcodeController.dispose();
    countryController.dispose();
    latController.dispose();
    lngController.dispose();
    screeningNumberCtrl.dispose();
    screeningIssueCtrl.dispose();
    screeningExpiryCtrl.dispose();
    screeningStateCtrl.dispose();
    wwccNumberCtrl.dispose();
    wwccStateCtrl.dispose();
    wwccExpiryCtrl.dispose();
    policeIssueCtrl.dispose();
    licenceNumberCtrl.dispose();
    licenceStateCtrl.dispose();
    licenceExpiryCtrl.dispose();
    vehiclePlateCtrl.dispose();
    vehicleStateCtrl.dispose();
    vehicleExpiryCtrl.dispose();
    for (final q in qualifications) {
      q.dispose();
    }
    super.onClose();
  }
}
