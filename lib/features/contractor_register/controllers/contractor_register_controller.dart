import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/constants/feature_flags.dart';
import '../../../core/errors/app_failure.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../data/models/contractor_register_models.dart';
import '../data/repositories/contractor_register_repository.dart';

/// Exact `doc_key` values validated by the backend on register.
abstract final class LegalDocKeys {
  static const platformTerms = 'platform_terms';
  static const privacyPolicy = 'privacy_policy';
}

class ContractorRegisterController extends GetxController {
  ContractorRegisterController({
    required ContractorRegisterRepository repository,
  }) : _repository = repository;

  final ContractorRegisterRepository _repository;

  final formKey = GlobalKey<FormState>();
  final fullNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final phoneController = TextEditingController();
  final dobController = TextEditingController();

  final isLoading = false.obs;
  final isInviteLoading = false.obs;
  final isPasswordVisible = false.obs;
  final acceptedTerms = false.obs;
  final acceptedPrivacy = false.obs;
  final termsMarkdown = ''.obs;
  final privacyMarkdown = ''.obs;
  final legalLoadError = RxnString();
  final invite = Rxn<ContractorInvitePublicOut>();
  final inviteLoadError = RxnString();

  String? _inviteToken;

  String get termsVersion => AppEnv.termsVersion;
  String get privacyVersion => AppEnv.privacyVersion;

  @override
  void onInit() {
    super.onInit();
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
      final terms = await rootBundle.loadString(
        'assets/legal/platform_terms.md',
      );
      final privacy = await rootBundle.loadString(
        'assets/legal/privacy_policy.md',
      );
      termsMarkdown.value = terms;
      privacyMarkdown.value = privacy;
      legalLoadError.value = null;
    } catch (e) {
      legalLoadError.value = 'Could not load legal documents.';
    }
  }

  void togglePasswordVisibility() => isPasswordVisible.toggle();

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

  Future<void> submit() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
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
    try {
      final phone = phoneController.text.trim();
      final dob = dobController.text.trim();
      await _repository.register(
        ContractorRegisterRequest(
          fullName: fullNameController.text.trim(),
          email: emailController.text.trim(),
          password: passwordController.text,
          phone: phone.isEmpty ? null : phone,
          dob: dob.isEmpty ? null : dob,
          inviteToken: _inviteToken,
          termsVersion: termsVersion,
          privacyVersion: privacyVersion,
        ),
      );
      Get.snackbar(
        'Account created',
        'Sign in with your new contractor account.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.success,
        colorText: AppColors.textLight,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
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
    Get.snackbar(
      'Registration failed',
      message,
      backgroundColor: AppColors.error,
      colorText: AppColors.textLight,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 5),
      icon: const Icon(Icons.error_rounded, color: Colors.white),
    );
  }

  @override
  void onClose() {
    fullNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    phoneController.dispose();
    dobController.dispose();
    super.onClose();
  }
}
