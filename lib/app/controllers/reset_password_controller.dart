import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/validation/password_validation.dart';
import '../../shared/widgets/app_toast.dart';
import '../data/datasources/remote/auth_remote_datasource.dart';
import '../data/models/auth/auth_error_model.dart';
import '../data/repositories/auth_repository.dart';
import '../routes/app_navigator.dart';
import '../routes/app_routes.dart';
import '../routes/middlewares/auth_route_utils.dart';

/// Public magic-link set-password (`/auth/reset-password/{token}`).
class ResetPasswordController extends GetxController {
  ResetPasswordController({required AuthRepository authRepository})
    : _authRepository = authRepository;

  final AuthRepository _authRepository;

  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  final isLoading = false.obs;
  final isPasswordVisible = false.obs;
  final isConfirmPasswordVisible = false.obs;
  final tokenMissing = false.obs;

  late final String token;

  @override
  void onInit() {
    super.onInit();
    token = (routeParam('token') ?? '').trim();
    tokenMissing.value = token.isEmpty;
  }

  void togglePasswordVisibility() => isPasswordVisible.toggle();
  void toggleConfirmPasswordVisibility() => isConfirmPasswordVisible.toggle();

  String? validatePassword(String? value) => PasswordValidation.validate(value);

  String? validateConfirm(String? value) {
    if (value != newPasswordController.text) return 'Passwords do not match';
    return null;
  }

  Future<void> submit() async {
    if (token.isEmpty) {
      AppToast.error('Invalid link', 'This invite link is missing a token.');
      return;
    }
    if (!formKey.currentState!.validate()) return;
    isLoading.value = true;
    try {
      await _authRepository.resetPassword(
        token: token,
        newPassword: newPasswordController.text,
      );
      AppToast.success(
        'Password set',
        'Please log in with your new password.',
      );
      AppNavigator.offAll(AppRoutes.login);
    } on AuthErrorModel catch (e) {
      AppToast.error('Error', e.detail);
    } on DioException catch (e) {
      final parsed = parseAuthError(e);
      AppToast.error(
        'Error',
        parsed?.detail ??
            e.message ??
            'Failed to set password. The link may have expired.',
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
