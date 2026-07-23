import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/network/must_change_password.dart';
import '../data/datasources/remote/auth_remote_datasource.dart';
import '../data/repositories/auth_repository.dart';
import '../routes/app_routes.dart';
import '../services/push_notification_service.dart';
import '../themes/app_colors.dart';

class AuthController extends GetxController {
  AuthController({required AuthRepository authRepository})
    : _authRepository = authRepository;

  final AuthRepository _authRepository;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  final isLoading = false.obs;
  final isPasswordVisible = false.obs;

  void togglePasswordVisibility() => isPasswordVisible.toggle();

  Future<void> showForgotPasswordDialog() async {
    final emailCtrl = TextEditingController(text: emailController.text.trim());
    final submitted = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Forgot password'),
        content: TextField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Account email',
            hintText: 'you@example.com',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
          TextButton(onPressed: () => Get.back(result: true), child: const Text('Send reset')),
        ],
      ),
    );
    if (submitted != true) {
      emailCtrl.dispose();
      return;
    }
    final email = emailCtrl.text.trim();
    emailCtrl.dispose();
    if (email.isEmpty || !GetUtils.isEmail(email)) {
      _showError('Enter a valid email');
      return;
    }
    try {
      final debugToken = await _authRepository.requestPasswordReset(email);
      if (debugToken != null && debugToken.isNotEmpty) {
        // DEV_MODE only — production responses omit the token.
        await Get.dialog(
          AlertDialog(
            title: const Text('Dev reset token'),
            content: SelectableText(debugToken),
            actions: [
              TextButton(onPressed: () => Get.back(), child: const Text('Close')),
            ],
          ),
        );
      } else {
        Get.snackbar(
          'Check your email',
          'If an account exists for that email, reset instructions were sent.',
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
        );
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String message) {
    Get.snackbar(
      'Error',
      message,
      backgroundColor: AppColors.error,
      colorText: AppColors.textLight,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 4),
      icon: const Icon(Icons.error_rounded, color: Colors.white),
    );
  }

  Future<void> login() async {
    if (!formKey.currentState!.validate()) return;

    isLoading.value = true;
    try {
      final tokens = await _authRepository.loginWithTokens(
        emailController.text.trim(),
        passwordController.text,
      );
      if (Get.isRegistered<PushNotificationService>()) {
        await Get.find<PushNotificationService>().registerCurrentDeviceToken();
      }
      redirectToFirstLoginIfNeeded(mustChangePassword: tokens.mustChangePassword);
      if (tokens.mustChangePassword) return;
      Get.offAllNamed(AppRoutes.adminBranchGateway);
    } on DioException catch (e) {
      if (isMustChangePasswordResponse(e)) {
        redirectToFirstLoginIfNeeded(mustChangePassword: true);
        return;
      }
      final parsed = parseAuthError(e);
      _showError(
        parsed?.detail ?? e.message ?? 'Network error. Please try again.',
      );
    } catch (e) {
      _showError(e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    await _authRepository.logout();
    emailController.clear();
    passwordController.clear();
    Get.offAllNamed(AppRoutes.gateway);
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}
