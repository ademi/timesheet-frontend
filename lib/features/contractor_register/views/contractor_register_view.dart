import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/responsive/max_width_box.dart';
import '../../../shared/widgets/markdown_viewer.dart';
import '../controllers/contractor_register_controller.dart';

class ContractorRegisterView extends GetView<ContractorRegisterController> {
  const ContractorRegisterView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Register as contractor'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: MaxWidthBox(
              maxWidth: Breakpoints.formMaxWidth,
              child: Form(
                key: controller.formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Create your contractor profile',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'After registering you will sign in. Company accounts '
                      'are created on the website.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Obx(() {
                      if (controller.isInviteLoading.value) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: LinearProgressIndicator(),
                        );
                      }
                      final error = controller.inviteLoadError.value;
                      if (error != null) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            error,
                            style: const TextStyle(color: AppColors.error),
                          ),
                        );
                      }
                      final invite = controller.invite.value;
                      if (invite == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'You were invited by ${invite.tenantName}. '
                          'Register with ${invite.email}.',
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                      );
                    }),
                    const SizedBox(height: 20),
                    _field(
                      controller: controller.fullNameController,
                      label: 'Full name',
                      icon: Icons.badge_outlined,
                      validator:
                          (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Full name is required'
                                  : null,
                    ),
                    const SizedBox(height: 12),
                    Obx(
                      () => _field(
                        controller: controller.emailController,
                        label: 'Email',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        readOnly: controller.invite.value != null,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Email is required';
                          }
                          if (!GetUtils.isEmail(v.trim())) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Obx(
                      () => _field(
                        controller: controller.passwordController,
                        label: 'Password',
                        icon: Icons.lock_outline,
                        obscureText: !controller.isPasswordVisible.value,
                        suffix: IconButton(
                          onPressed: controller.togglePasswordVisibility,
                          icon: Icon(
                            controller.isPasswordVisible.value
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Password is required';
                          }
                          if (v.length < 8) {
                            return 'Minimum 8 characters';
                          }
                          if (!RegExp(r'[A-Z]').hasMatch(v)) {
                            return 'Include an uppercase letter';
                          }
                          if (!RegExp(r'[a-z]').hasMatch(v)) {
                            return 'Include a lowercase letter';
                          }
                          if (!RegExp(r'\d').hasMatch(v)) {
                            return 'Include a digit';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    _field(
                      controller: controller.phoneController,
                      label: 'Phone (optional)',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      hint: '+614… or 04…',
                    ),
                    const SizedBox(height: 12),
                    _field(
                      controller: controller.dobController,
                      label: 'Date of birth (optional)',
                      icon: Icons.cake_outlined,
                      readOnly: true,
                      hint: 'YYYY-MM-DD',
                      onTap: () => controller.pickDob(context),
                    ),
                    const SizedBox(height: 24),
                    Obx(() {
                      if (controller.legalLoadError.value != null) {
                        return Text(
                          controller.legalLoadError.value!,
                          style: const TextStyle(color: AppColors.error),
                        );
                      }
                      return const SizedBox.shrink();
                    }),
                    _LegalBlock(
                      title: 'Platform Terms',
                      markdown: controller.termsMarkdown,
                      accepted: controller.acceptedTerms,
                      acceptLabel: 'I accept the Platform Terms',
                    ),
                    const SizedBox(height: 16),
                    _LegalBlock(
                      title: 'Privacy Policy',
                      markdown: controller.privacyMarkdown,
                      accepted: controller.acceptedPrivacy,
                      acceptLabel: 'I accept the Privacy Policy',
                    ),
                    const SizedBox(height: 24),
                    Obx(
                      () => SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed:
                              controller.isLoading.value ||
                                      controller.isInviteLoading.value
                                  ? null
                                  : controller.submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child:
                              controller.isLoading.value
                                  ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                  : const Text(
                                    'Create account',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: controller.goToLogin,
                      child: const Text('Already have an account? Sign in'),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    bool readOnly = false,
    Widget? suffix,
    VoidCallback? onTap,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscureText,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.primaryDark),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.cardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
      ),
    );
  }
}

class _LegalBlock extends StatelessWidget {
  const _LegalBlock({
    required this.title,
    required this.markdown,
    required this.accepted,
    required this.acceptLabel,
  });

  final String title;
  final RxString markdown;
  final RxBool accepted;
  final String acceptLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 180,
            child: Obx(
              () =>
                  markdown.value.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : MarkdownViewer(markdown: markdown.value),
            ),
          ),
          const Divider(height: 1),
          Obx(
            () => CheckboxListTile(
              value: accepted.value,
              onChanged: (v) => accepted.value = v ?? false,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(acceptLabel, style: const TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}
