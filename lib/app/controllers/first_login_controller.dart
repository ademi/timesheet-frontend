import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/datasources/remote/auth_remote_datasource.dart';
import '../data/models/auth/auth_error_model.dart';
import '../data/repositories/auth_repository.dart';
import '../routes/app_routes.dart';
import '../themes/app_colors.dart';

class FirstLoginController extends GetxController {
  FirstLoginController({required AuthRepository authRepository})
      : _authRepository = authRepository;

  final AuthRepository _authRepository;

  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  final isLoading = false.obs;
  final isPasswordVisible = false.obs;
  final isConfirmPasswordVisible = false.obs;

  void togglePasswordVisibility() => isPasswordVisible.toggle();
  void toggleConfirmPasswordVisibility() => isConfirmPasswordVisible.toggle();

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Password must be at least 8 characters';
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Must contain an uppercase letter';
    }
    if (!value.contains(RegExp(r'[0-9]'))) return 'Must contain a number';
    return null;
  }

  String? validateConfirm(String? value) {
    if (value != newPasswordController.text) return 'Passwords do not match';
    return null;
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    isLoading.value = true;
    try {
      await _authRepository.completeFirstLogin(newPasswordController.text);
      Get.snackbar(
        'Password set',
        'Please log in again with your new password.',
        backgroundColor: AppColors.primary,
        colorText: AppColors.textLight,
        snackPosition: SnackPosition.BOTTOM,
      );
      Get.offAllNamed(AppRoutes.login);
    } on AuthErrorModel catch (e) {
      Get.snackbar(
        'Error',
        e.detail,
        backgroundColor: AppColors.error,
        colorText: AppColors.textLight,
        snackPosition: SnackPosition.BOTTOM,
      );
    } on DioException catch (e) {
      final parsed = parseAuthError(e);
      Get.snackbar(
        'Error',
        parsed?.detail ?? e.message ?? 'Failed to set password. Please try again.',
        backgroundColor: AppColors.error,
        colorText: AppColors.textLight,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }
}
