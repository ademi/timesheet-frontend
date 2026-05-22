import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/datasources/remote/auth_remote_datasource.dart';
import '../data/models/auth/auth_error_model.dart';
import '../data/models/auth/verify_user_response_model.dart';
import '../data/repositories/auth_repository.dart';
import '../routes/app_routes.dart';
import '../themes/app_colors.dart';
import 'gateway_controller.dart';

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

  /// Delegates to [AuthRepository.verifyUser] (auth `plainDio` / existing [ApiClient]).
  Future<VerifyUserResponseModel> verifyUser(String email, String password) {
    return _authRepository.verifyUser(email, password);
  }

  Future<void> login() async {
    if (!formKey.currentState!.validate()) return;

    isLoading.value = true;
    try {
      await _authRepository.login(
        emailController.text.trim(),
        passwordController.text,
      );
      final gateway = Get.find<GatewayController>();
      final destination =
          gateway.selectedRole.value == UserRole.admin
              ? AppRoutes.adminPanel
              : AppRoutes.home;
      Get.offAllNamed(destination);
    } on AuthErrorModel catch (e) {
      _showError(e.detail);
    } on DioException catch (e) {
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
