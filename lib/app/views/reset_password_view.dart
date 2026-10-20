import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/responsive/breakpoints.dart';
import '../../core/responsive/max_width_box.dart';
import '../controllers/reset_password_controller.dart';
import '../routes/app_navigator.dart';
import '../routes/app_routes.dart';
import '../themes/app_colors.dart';

class ResetPasswordView extends StatelessWidget {
  const ResetPasswordView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ResetPasswordController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Your Password'),
        backgroundColor: AppColors.primary,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: MaxWidthBox(
              maxWidth: Breakpoints.formMaxWidth,
              child: Obx(() {
                if (controller.tokenMissing.value) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.link_off,
                        size: 64,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Invalid invite link',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'This link is missing or incomplete. Ask your admin '
                        'to send a new staff invite.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => AppNavigator.offAll(AppRoutes.login),
                        child: const Text('Go to login'),
                      ),
                    ],
                  );
                }
                return Form(
                  key: controller.formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.lock_reset_rounded,
                        size: 64,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Create your password',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You’ve been invited as staff. Set a password to '
                        'finish activating your account.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textDark.withValues(alpha: 0.65),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      Obx(
                        () => TextFormField(
                          controller: controller.newPasswordController,
                          obscureText: !controller.isPasswordVisible.value,
                          decoration: InputDecoration(
                            labelText: 'New Password',
                            suffixIcon: IconButton(
                              icon: Icon(
                                controller.isPasswordVisible.value
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: controller.togglePasswordVisibility,
                            ),
                          ),
                          validator: controller.validatePassword,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Obx(
                        () => TextFormField(
                          controller: controller.confirmPasswordController,
                          obscureText:
                              !controller.isConfirmPasswordVisible.value,
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            suffixIcon: IconButton(
                              icon: Icon(
                                controller.isConfirmPasswordVisible.value
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed:
                                  controller.toggleConfirmPasswordVisibility,
                            ),
                          ),
                          validator: controller.validateConfirm,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Obx(
                        () => ElevatedButton(
                          onPressed:
                              controller.isLoading.value
                                  ? null
                                  : controller.submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.cta,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child:
                              controller.isLoading.value
                                  ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : const Text(
                                    'Set Password',
                                    style: TextStyle(color: Colors.white),
                                  ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
