import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../shared/widgets/async_action.dart';
import '../controllers/clients_controller.dart';

class ClientSiteFormView extends GetView<ClientsController> {
  const ClientSiteFormView({super.key});

  @override
  Widget build(BuildContext context) {
    final isEdit = controller.editingSite != null;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(isEdit ? 'Edit site' : 'Add site')),
      body: Obx(() {
        final err = controller.errorMessage.value;
        final hint = controller.geocodeHint.value;
        final busy =
            controller.isSaving.value || controller.isGeocoding.value;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (err != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(err, style: const TextStyle(color: AppColors.error)),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: controller.siteNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.siteAddressCtrl,
              decoration: const InputDecoration(
                labelText: 'Address line 1 *',
                border: OutlineInputBorder(),
                helperText: 'Required to look up coordinates',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.siteCityCtrl,
              decoration: const InputDecoration(
                labelText: 'City *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.siteStateCtrl,
              decoration: const InputDecoration(
                labelText: 'State',
                border: OutlineInputBorder(),
                helperText: 'Optional (e.g. NSW)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.siteCountryCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Country *',
                hintText: 'AU',
                border: OutlineInputBorder(),
                helperText: '2-letter ISO code (e.g. AU, US, GB)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.sitePostalCtrl,
              decoration: const InputDecoration(
                labelText: 'Postal code',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            AsyncOutlinedButton(
              onPressed: () => controller.geocodeFromAddress(),
              isLoading: busy,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                foregroundColor: AppColors.primary,
              ),
              child: const Text('Look up coordinates from address'),
            ),
            if (hint != null) ...[
              const SizedBox(height: 8),
              Text(
                hint,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: controller.siteIsPrimary.value,
              onChanged: (v) => controller.siteIsPrimary.value = v,
              title: const Text('Primary site'),
            ),
            const SizedBox(height: 16),
            AsyncElevatedButton(
              onPressed: controller.saveSite,
              isLoading: busy,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(isEdit ? 'Save site' : 'Create site'),
            ),
          ],
        );
      }),
    );
  }
}
