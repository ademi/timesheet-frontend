import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../routes/app_routes.dart';

class AuthController extends GetxController {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  final isLoading = false.obs;
  final isPasswordVisible = false.obs;

  void togglePasswordVisibility() => isPasswordVisible.toggle();

  // Mock login — no backend in phase 1
  Future<void> login() async {
    if (!formKey.currentState!.validate()) return;

    isLoading(true);
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));
    isLoading(false);

    Get.offAllNamed(AppRoutes.home);
  }

  void logout() {
    emailController.clear();
    passwordController.clear();
    Get.offAllNamed(AppRoutes.login);
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}
