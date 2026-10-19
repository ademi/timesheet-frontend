import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../app/utils/email_utils.dart';
import '../../../shared/utils/abn_utils.dart';
import '../../../shared/widgets/async_action.dart';
import '../../../shared/widgets/au_state_dropdown.dart';
import '../controllers/contractor_register_controller.dart';

class RegisterInviteBanner extends StatelessWidget {
  const RegisterInviteBanner({super.key, required this.controller});

  final ContractorRegisterController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isInviteLoading.value) {
        return const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: LinearProgressIndicator(),
        );
      }
      final error = controller.inviteLoadError.value;
      if (error != null) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(error, style: const TextStyle(color: AppColors.error)),
        );
      }
      final invite = controller.invite.value;
      if (invite == null) return const SizedBox.shrink();
      final categories = invite.requiredCategories;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You were invited by ${invite.tenantName}. Register with ${invite.email}.',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            if (categories.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'After signup you will need to upload: ${categories.join(', ')}.',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}

class RegisterIdentityStep extends StatelessWidget {
  const RegisterIdentityStep({super.key, required this.controller});

  final ContractorRegisterController controller;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: controller.identityFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RegisterInviteBanner(controller: controller),
          const Text(
            'Account & contact',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 12),
          _field(
            controller: controller.fullNameController,
            label: 'Full name (optional)',
            icon: Icons.badge_outlined,
          ),
          const SizedBox(height: 12),
          Obx(
            () => _field(
              controller: controller.emailController,
              label: 'Email *',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              readOnly: controller.invite.value != null,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email is required';
                if (!EmailUtils.isValid(v.trim())) return EmailUtils.formatHint;
                return null;
              },
            ),
          ),
          const SizedBox(height: 12),
          Obx(
            () => _field(
              controller: controller.passwordController,
              label: 'Password *',
              icon: Icons.lock_outline,
              obscureText: !controller.isPasswordVisible.value,
              suffix: IconButton(
                onPressed: controller.togglePasswordVisibility,
                icon: Icon(
                  controller.isPasswordVisible.value
                      ? Icons.visibility_off
                      : Icons.visibility,
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password is required';
                if (v.length < 8) return 'Minimum 8 characters';
                if (!RegExp(r'[A-Z]').hasMatch(v)) {
                  return 'Include an uppercase letter';
                }
                if (!RegExp(r'[a-z]').hasMatch(v)) {
                  return 'Include a lowercase letter';
                }
                if (!RegExp(r'\d').hasMatch(v)) return 'Include a digit';
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
          ),
          const SizedBox(height: 12),
          _field(
            controller: controller.dobController,
            label: 'Date of birth (optional)',
            icon: Icons.cake_outlined,
            readOnly: true,
            onTap: () => controller.pickDob(context),
          ),
          const SizedBox(height: 20),
          const Text(
            'Residential address (optional)',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          _field(
            controller: controller.addressLine1Controller,
            label: 'Address line 1',
            icon: Icons.home_outlined,
            onChanged: (_) => controller.invalidateAddressConfirm(),
          ),
          const SizedBox(height: 12),
          _field(
            controller: controller.addressLine2Controller,
            label: 'Address line 2',
            icon: Icons.home_outlined,
          ),
          const SizedBox(height: 12),
          _field(
            controller: controller.suburbController,
            label: 'Suburb / city',
            icon: Icons.location_city_outlined,
            onChanged: (_) => controller.invalidateAddressConfirm(),
          ),
          const SizedBox(height: 12),
          AuStateDropdown(
            value: controller.stateController.text,
            profileStyle: true,
            onChanged: (selected) {
              controller.stateController.text = selected;
              controller.invalidateAddressConfirm();
            },
          ),
          const SizedBox(height: 12),
          _field(
            controller: controller.postcodeController,
            label: 'Postcode',
            icon: Icons.markunread_mailbox_outlined,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          _field(
            controller: controller.countryController,
            label: 'Country',
            icon: Icons.public_outlined,
          ),
          const SizedBox(height: 12),
          _AddressGeocodePanel(controller: controller),
          const SizedBox(height: 20),
          _field(
            controller: controller.abnController,
            label: 'ABN (optional)',
            icon: Icons.apartment_outlined,
            keyboardType: TextInputType.number,
            validator: (v) => AbnUtils.formValidator(v),
          ),
          const SizedBox(height: 12),
          const Text(
            'Bank payment details can be added after signup under Profile.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _AddressGeocodePanel extends StatelessWidget {
  const _AddressGeocodePanel({required this.controller});

  final ContractorRegisterController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final formatted = controller.geocodeFormattedAddress.value;
      final confirmed = controller.addressConfirmed.value;
      final lookingUp = controller.isGeocoding.value;

      if (formatted == null && !confirmed) {
        return AsyncOutlinedButton(
          onPressed: controller.lookupAddress,
          isLoading: lookingUp,
          child: const Text('Look up address'),
        );
      }

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: confirmed ? AppColors.primaryLight : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: confirmed ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              formatted ?? 'Address confirmed',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            if (!confirmed)
              AsyncElevatedButton(
                onPressed: controller.confirmAddress,
                isLoading: false,
                child: const Text('Confirm address'),
              )
            else
              OutlinedButton(
                onPressed: controller.editAddressLookup,
                child: const Text('Edit address'),
              ),
          ],
        ),
      );
    });
  }
}

Widget _field({
  required TextEditingController controller,
  required String label,
  required IconData icon,
  String? Function(String?)? validator,
  TextInputType? keyboardType,
  bool obscureText = false,
  bool readOnly = false,
  Widget? suffix,
  VoidCallback? onTap,
  ValueChanged<String>? onChanged,
}) {
  return TextFormField(
    controller: controller,
    validator: validator,
    keyboardType: keyboardType,
    obscureText: obscureText,
    readOnly: readOnly,
    onTap: onTap,
    onChanged: onChanged,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.primaryDark),
      suffixIcon: suffix,
      filled: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
