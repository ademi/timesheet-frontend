import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../shared/utils/abn_utils.dart';
import '../../../shared/widgets/async_action.dart';
import '../controllers/contractor_profile_controller.dart';

class ContractorProfileSections extends StatelessWidget {
  const ContractorProfileSections({super.key, required this.controller});

  final ContractorProfileController controller;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: controller.profileFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle('Identity & contact'),
          _field(
            controller: controller.fullNameCtrl,
            label: 'Full name',
            icon: Icons.badge_outlined,
          ),
          const SizedBox(height: 12),
          _field(
            controller: controller.phoneCtrl,
            label: 'Phone',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          _field(
            controller: controller.dobCtrl,
            label: 'Date of birth',
            icon: Icons.cake_outlined,
            readOnly: true,
            onTap: () => controller.pickDob(context),
          ),
          const SizedBox(height: 20),
          _sectionTitle('Address'),
          _field(
            controller: controller.addressLine1Ctrl,
            label: 'Address line 1',
            icon: Icons.home_outlined,
            onChanged: (_) => controller.invalidateAddressConfirm(),
          ),
          const SizedBox(height: 12),
          _field(
            controller: controller.addressLine2Ctrl,
            label: 'Address line 2',
            icon: Icons.home_outlined,
          ),
          const SizedBox(height: 12),
          _field(
            controller: controller.suburbCtrl,
            label: 'Suburb / city',
            icon: Icons.location_city_outlined,
            onChanged: (_) => controller.invalidateAddressConfirm(),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: ContractorProfileController.auStates.contains(
              controller.stateCtrl.text.trim(),
            )
                ? controller.stateCtrl.text.trim()
                : ContractorProfileController.auStates.first,
            decoration: const InputDecoration(
              labelText: 'State',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final s in ContractorProfileController.auStates)
                DropdownMenuItem(value: s, child: Text(s)),
            ],
            onChanged: (v) {
              if (v == null) return;
              controller.stateCtrl.text = v;
              controller.invalidateAddressConfirm();
            },
          ),
          const SizedBox(height: 12),
          _field(
            controller: controller.postcodeCtrl,
            label: 'Postcode',
            icon: Icons.markunread_mailbox_outlined,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          _field(
            controller: controller.countryCtrl,
            label: 'Country',
            icon: Icons.public_outlined,
          ),
          const SizedBox(height: 12),
          _AddressGeocodePanel(controller: controller),
          const SizedBox(height: 20),
          _sectionTitle('Business & payment'),
          _field(
            controller: controller.abnCtrl,
            label: 'ABN',
            icon: Icons.apartment_outlined,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(11),
            ],
            validator: (v) => AbnUtils.formValidator(v),
          ),
          const SizedBox(height: 12),
          _field(
            controller: controller.accountNameCtrl,
            label: 'Account name (optional)',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 12),
          _field(
            controller: controller.bsbCtrl,
            label: 'BSB (optional)',
            icon: Icons.account_balance_outlined,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
          ),
          const SizedBox(height: 12),
          _field(
            controller: controller.accountNumberCtrl,
            label: 'Account number (optional)',
            icon: Icons.pin_outlined,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
          ),
          const SizedBox(height: 20),
          _sectionTitle('Screening'),
          _field(
            controller: controller.screeningNumberCtrl,
            label: 'NDIS screening number',
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
            onPick: () =>
                controller.pickDate(context, controller.screeningIssueCtrl),
          ),
          const SizedBox(height: 12),
          _dateField(
            context: context,
            controller: controller.screeningExpiryCtrl,
            label: 'Expiry date',
            onPick: () =>
                controller.pickDate(context, controller.screeningExpiryCtrl),
          ),
          const SizedBox(height: 12),
          _field(
            controller: controller.screeningStateCtrl,
            label: 'State/territory',
            icon: Icons.map_outlined,
          ),
          const SizedBox(height: 20),
          _sectionTitle('Qualifications'),
          Obx(() {
            return Column(
              children: [
                for (var i = 0; i < controller.qualifications.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _qualCard(context, i),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: controller.addQualification,
                  icon: const Icon(Icons.add),
                  label: const Text('Add qualification'),
                ),
              ],
            );
          }),
          const SizedBox(height: 20),
          _sectionTitle('Checks'),
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
            onPick: () =>
                controller.pickDate(context, controller.wwccExpiryCtrl),
          ),
          const SizedBox(height: 16),
          _dateField(
            context: context,
            controller: controller.policeIssueCtrl,
            label: 'Police check issue date',
            onPick: () =>
                controller.pickDate(context, controller.policeIssueCtrl),
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
      ),
    );
  }

  Widget _qualCard(BuildContext context, int index) {
    final row = controller.qualifications[index];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: ContractorProfileController.qualTypeOptions.contains(row.type)
                  ? row.type
                  : ContractorProfileController.qualTypeOptions.first,
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final t in ContractorProfileController.qualTypeOptions)
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

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    );
  }
}

class _AddressGeocodePanel extends StatelessWidget {
  const _AddressGeocodePanel({required this.controller});

  final ContractorProfileController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final formatted = controller.geocodeFormattedAddress.value;
      final confirmed = controller.addressConfirmed.value;
      if (formatted == null && !confirmed) {
        return AsyncOutlinedButton(
          onPressed: controller.lookupAddress,
          isLoading: controller.isGeocoding.value,
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
  bool readOnly = false,
  List<TextInputFormatter>? inputFormatters,
  VoidCallback? onTap,
  ValueChanged<String>? onChanged,
}) {
  return TextFormField(
    controller: controller,
    validator: validator,
    keyboardType: keyboardType,
    readOnly: readOnly,
    inputFormatters: inputFormatters,
    onTap: onTap,
    onChanged: onChanged,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.primaryDark),
      filled: true,
      fillColor: AppColors.cardBackground,
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
      fillColor: AppColors.cardBackground,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
