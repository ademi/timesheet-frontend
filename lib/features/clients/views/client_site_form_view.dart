import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/async_action.dart';
import '../controllers/clients_controller.dart';

/// Australian states/territories for site forms.
const auStates = <String>[
  'NSW',
  'VIC',
  'QLD',
  'WA',
  'SA',
  'TAS',
  'ACT',
  'NT',
];

class ClientSiteFormView extends GetView<ClientsController> {
  const ClientSiteFormView({super.key});

  @override
  Widget build(BuildContext context) {
    final isEdit = controller.editingSite != null;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(isEdit ? 'Edit location' : 'Add location')),
      body: Obx(() {
        final err = controller.errorMessage.value;
        final busy =
            controller.isSaving.value || controller.isGeocoding.value;
        final stateValue = controller.siteState.value;
        final stateItems = {stateValue, ...auStates}.toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PageContent(
              width: PageContentWidth.narrow,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (err != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.errorBackground,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            err,
                            style: const TextStyle(color: AppColors.error),
                          ),
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
                      DropdownButtonFormField<String>(
                        value: stateValue,
                        items: [
                          for (final s in stateItems)
                            DropdownMenuItem(value: s, child: Text(s)),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          controller.siteState.value = v;
                          controller.siteStateCtrl.text = v;
                        },
                        decoration: const InputDecoration(
                          labelText: 'State',
                          border: OutlineInputBorder(),
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
                        child: Text(
                          isEdit ? 'Save location' : 'Create location',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
