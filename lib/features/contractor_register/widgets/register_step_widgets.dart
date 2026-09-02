import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../app/utils/email_utils.dart';
import '../../../shared/utils/abn_utils.dart';
import '../../../shared/widgets/async_action.dart';
import '../../../shared/widgets/markdown_viewer.dart';
import '../controllers/contractor_register_controller.dart';

class RegisterStepIndicator extends StatelessWidget {
  const RegisterStepIndicator({super.key, required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    const labels = ContractorRegisterController.stepLabels;
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= step ? AppColors.primary : AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  labels[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color:
                        i <= step ? AppColors.textDark : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

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
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
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
          DropdownButtonFormField<String>(
            value: ContractorRegisterController.auStates.contains(
              controller.stateController.text.trim(),
            )
                ? controller.stateController.text.trim()
                : ContractorRegisterController.auStates.first,
            decoration: const InputDecoration(
              labelText: 'State',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final s in ContractorRegisterController.auStates)
                DropdownMenuItem(value: s, child: Text(s)),
            ],
            onChanged: (v) {
              if (v == null) return;
              controller.stateController.text = v;
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

class RegisterScreeningStep extends StatelessWidget {
  const RegisterScreeningStep({super.key, required this.controller});

  final ContractorRegisterController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'NDIS Worker Screening (optional)',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 12),
        _field(
          controller: controller.screeningNumberCtrl,
          label: 'Screening number',
          icon: Icons.verified_user_outlined,
        ),
        const SizedBox(height: 12),
        Obx(
          () => DropdownButtonFormField<String>(
            value: controller.screeningStatus.value,
            decoration: const InputDecoration(
              labelText: 'Clearance status',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'cleared', child: Text('Cleared')),
              DropdownMenuItem(value: 'excluded', child: Text('Excluded')),
              DropdownMenuItem(value: 'pending', child: Text('Pending')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (v) => controller.screeningStatus.value = v,
          ),
        ),
        const SizedBox(height: 12),
        _dateField(
          context: context,
          controller: controller.screeningIssueCtrl,
          label: 'Issue date',
          onPick: () => controller.pickDate(
            context,
            controller.screeningIssueCtrl,
          ),
        ),
        const SizedBox(height: 12),
        _dateField(
          context: context,
          controller: controller.screeningExpiryCtrl,
          label: 'Expiry date',
          onPick: () => controller.pickDate(
            context,
            controller.screeningExpiryCtrl,
          ),
        ),
        const SizedBox(height: 12),
        _field(
          controller: controller.screeningStateCtrl,
          label: 'State/territory of issue',
          icon: Icons.map_outlined,
        ),
      ],
    );
  }
}

class RegisterQualificationsStep extends StatelessWidget {
  const RegisterQualificationsStep({super.key, required this.controller});

  final ContractorRegisterController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Qualifications (optional)',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add certificates or training. Upload evidence after signup.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < controller.qualifications.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            _QualRow(
              controller: controller,
              index: i,
              row: controller.qualifications[i],
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: controller.addQualification,
            icon: const Icon(Icons.add),
            label: const Text('Add qualification'),
          ),
        ],
      );
    });
  }
}

class _QualRow extends StatelessWidget {
  const _QualRow({
    required this.controller,
    required this.index,
    required this.row,
  });

  final ContractorRegisterController controller;
  final int index;
  final RegisterQualRow row;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: ContractorRegisterController.qualTypeOptions.contains(row.type)
                  ? row.type
                  : ContractorRegisterController.qualTypeOptions.first,
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final t in ContractorRegisterController.qualTypeOptions)
                  DropdownMenuItem(value: t, child: Text(t)),
              ],
              onChanged: (v) {
                if (v != null) row.type = v;
                controller.qualifications.refresh();
              },
            ),
            const SizedBox(height: 12),
            _dateField(
              context: context,
              controller: row.issueDateCtrl,
              label: 'Issue date',
              onPick: () => controller.pickDate(context, row.issueDateCtrl),
            ),
            const SizedBox(height: 12),
            _dateField(
              context: context,
              controller: row.expiryDateCtrl,
              label: 'Expiry date',
              onPick: () => controller.pickDate(context, row.expiryDateCtrl),
            ),
            if (controller.qualifications.length > 1) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => controller.removeQualification(index),
                  child: const Text('Remove'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class RegisterChecksStep extends StatelessWidget {
  const RegisterChecksStep({super.key, required this.controller});

  final ContractorRegisterController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Checks (optional)',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 12),
        _field(
          controller: controller.wwccNumberCtrl,
          label: 'WWCC number',
          icon: Icons.child_care_outlined,
        ),
        const SizedBox(height: 12),
        _field(
          controller: controller.wwccStateCtrl,
          label: 'WWCC state',
          icon: Icons.map_outlined,
        ),
        const SizedBox(height: 12),
        _dateField(
          context: context,
          controller: controller.wwccExpiryCtrl,
          label: 'WWCC expiry',
          onPick: () => controller.pickDate(context, controller.wwccExpiryCtrl),
        ),
        const SizedBox(height: 16),
        _dateField(
          context: context,
          controller: controller.policeIssueCtrl,
          label: 'Police check issue date',
          onPick: () => controller.pickDate(context, controller.policeIssueCtrl),
        ),
        const SizedBox(height: 16),
        _field(
          controller: controller.licenceNumberCtrl,
          label: 'Driver licence number',
          icon: Icons.directions_car_outlined,
        ),
        const SizedBox(height: 12),
        _field(
          controller: controller.licenceStateCtrl,
          label: 'Licence state',
          icon: Icons.map_outlined,
        ),
        const SizedBox(height: 12),
        _dateField(
          context: context,
          controller: controller.licenceExpiryCtrl,
          label: 'Licence expiry',
          onPick: () =>
              controller.pickDate(context, controller.licenceExpiryCtrl),
        ),
        const SizedBox(height: 16),
        _field(
          controller: controller.vehiclePlateCtrl,
          label: 'Vehicle plate',
          icon: Icons.local_shipping_outlined,
        ),
        const SizedBox(height: 12),
        _field(
          controller: controller.vehicleStateCtrl,
          label: 'Vehicle state',
          icon: Icons.map_outlined,
        ),
        const SizedBox(height: 12),
        _dateField(
          context: context,
          controller: controller.vehicleExpiryCtrl,
          label: 'Registration expiry',
          onPick: () =>
              controller.pickDate(context, controller.vehicleExpiryCtrl),
        ),
      ],
    );
  }
}

class RegisterLegalStep extends StatelessWidget {
  const RegisterLegalStep({super.key, required this.controller});

  final ContractorRegisterController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
      ],
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
    return Material(
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          SizedBox(
            height: 180,
            child: Obx(
              () => markdown.value.isEmpty
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

Widget _dateField({
  required BuildContext context,
  required TextEditingController controller,
  required String label,
  required VoidCallback onPick,
}) {
  return TextFormField(
    controller: controller,
    readOnly: true,
    onTap: onPick,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: const Icon(Icons.calendar_today_outlined),
      filled: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
