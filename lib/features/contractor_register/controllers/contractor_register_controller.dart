import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/utils/email_utils.dart';

import '../../../app/routes/app_navigator.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/constants/australian_states.dart';
import '../../../core/errors/app_failure.dart';
import '../../../features/clients/data/models/client_models.dart'
    as client_models;
import '../../../features/clients/utils/site_geocode_apply.dart';
import '../../../shared/utils/abn_utils.dart';
import '../../../shared/widgets/app_toast.dart';
import '../data/models/contractor_register_models.dart';
import '../data/repositories/contractor_register_repository.dart';

/// Slim public register: Identity only. Screening / Qualifications / Checks /
/// Legal live post-login (Profile + onboarding funnel).
class ContractorRegisterController extends GetxController {
  ContractorRegisterController({
    required ContractorRegisterRepository repository,
  }) : _repository = repository;

  final ContractorRegisterRepository _repository;

  /// Identity-only register (former multi-step wizard removed).
  static const stepLabels = ['Identity'];

  final identityFormKey = GlobalKey<FormState>();

  final fullNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final phoneController = TextEditingController();
  final dobController = TextEditingController();
  final abnController = TextEditingController();

  final addressLine1Controller = TextEditingController();
  final addressLine2Controller = TextEditingController();
  final suburbController = TextEditingController();
  final stateController = TextEditingController();
  final postcodeController = TextEditingController();
  final countryController = TextEditingController(text: 'AU');
  final latController = TextEditingController();
  final lngController = TextEditingController();

  final isLoading = false.obs;
  final isInviteLoading = false.obs;
  final isGeocoding = false.obs;
  final isPasswordVisible = false.obs;
  final invite = Rxn<ContractorInvitePublicOut>();
  final inviteLoadError = RxnString();
  final errorMessage = RxnString();
  final geocodeFormattedAddress = RxnString();
  final addressConfirmed = false.obs;

  String? _inviteToken;

  /// Last register request built for submit (exposed for tests).
  @visibleForTesting
  ContractorRegisterRequest? lastRegisterRequest;

  /// Resolves invite token from path param, legacy query param, or web URI.
  @visibleForTesting
  static String? resolveInviteToken({
    Map<String, String?>? parameters,
    Uri? baseUri,
  }) {
    final pathToken = parameters?['token']?.trim();
    if (pathToken != null && pathToken.isNotEmpty) return pathToken;
    final legacyParam = parameters?['invite']?.trim();
    if (legacyParam != null && legacyParam.isNotEmpty) return legacyParam;
    if (baseUri != null) {
      final queryToken = baseUri.queryParameters['invite']?.trim();
      if (queryToken != null && queryToken.isNotEmpty) return queryToken;
      // Deep-link fallback when GoRouter → Get.parameters sync did not run yet
      // (e.g. cold open of `/contractor/register/{token}` on web).
      final segments = baseUri.pathSegments;
      if (segments.length >= 3 &&
          segments[0] == 'contractor' &&
          segments[1] == 'register') {
        final fromPath = segments[2].trim();
        if (fromPath.isNotEmpty) return fromPath;
      }
    }
    return null;
  }

  @visibleForTesting
  String? get inviteTokenForTest => _inviteToken;

  @override
  void onInit() {
    super.onInit();
    stateController.text = kDefaultAustralianState;
    _loadInviteFromRoute();
  }

  Future<void> _loadInviteFromRoute() async {
    final token = resolveInviteToken(
      parameters: Get.parameters,
      baseUri: kIsWeb ? Uri.base : null,
    );
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

  void togglePasswordVisibility() => isPasswordVisible.toggle();

  String? _identityValidationError() {
    final email = emailController.text.trim();
    if (email.isEmpty) return 'Email is required';
    if (!EmailUtils.isValid(email)) return EmailUtils.formatHint;

    final password = passwordController.text;
    if (password.isEmpty) return 'Password is required';
    if (password.length < 8) return 'Minimum 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Include an uppercase letter';
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Include a lowercase letter';
    }
    if (!RegExp(r'\d').hasMatch(password)) return 'Include a digit';

    final abnErr = AbnUtils.formValidator(abnController.text);
    if (abnErr != null) return abnErr;

    return null;
  }

  bool _ensureIdentityValidForSubmit() {
    final formState = identityFormKey.currentState;
    if (formState != null) return formState.validate();

    final error = _identityValidationError();
    if (error != null) {
      _showError(error);
      return false;
    }
    return true;
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
          country:
              countryController.text.trim().isEmpty
                  ? 'AU'
                  : countryController.text.trim(),
          state:
              stateController.text.trim().isEmpty
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

  Map<String, dynamic>? _metadataPayload() {
    final lat = double.tryParse(latController.text.trim());
    final lng = double.tryParse(lngController.text.trim());
    if (lat == null || lng == null) return null;
    return {
      'location': {'latitude': lat, 'longitude': lng},
    };
  }

  /// Builds the Identity-only register request (no compliance / terms / privacy).
  @visibleForTesting
  ContractorRegisterRequest buildRegisterRequest() {
    String? abn;
    try {
      abn = AbnUtils.normalizeOrNull(abnController.text);
    } on FormatException {
      rethrow;
    }
    final phone = phoneController.text.trim();
    final dob = dobController.text.trim();
    return ContractorRegisterRequest(
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
      metadata: _metadataPayload(),
      inviteToken: _inviteToken,
    );
  }

  Future<void> submit() async {
    if (isInviteLoading.value) return;
    if (!_ensureIdentityValidForSubmit()) return;

    isLoading.value = true;
    errorMessage.value = null;
    try {
      final ContractorRegisterRequest request;
      try {
        request = buildRegisterRequest();
      } on FormatException catch (e) {
        _showError(e.message);
        return;
      }
      lastRegisterRequest = request;

      await _repository.register(request);
      // Do NOT mark platform complete — first login must hit legal/notices/consents.
      AppToast.success(
        'Account created',
        'Sign in with your new contractor account.',
      );
      AppNavigator.offAll(AppRoutes.login);
    } on AppFailure catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError(e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  void goToLogin() => AppNavigator.go(AppRoutes.login);

  void _showError(String message) {
    errorMessage.value = message;
    AppToast.error(
      'Registration failed',
      message,
      duration: const Duration(seconds: 5),
    );
  }

  @override
  void onClose() {
    fullNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    phoneController.dispose();
    dobController.dispose();
    abnController.dispose();
    addressLine1Controller.dispose();
    addressLine2Controller.dispose();
    suburbController.dispose();
    stateController.dispose();
    postcodeController.dispose();
    countryController.dispose();
    latController.dispose();
    lngController.dispose();
    super.onClose();
  }
}
