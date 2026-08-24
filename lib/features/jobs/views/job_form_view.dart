import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/async_action.dart';
import '../../../shared/widgets/ndis_support_item_picker.dart';
import '../controllers/jobs_controller.dart';
import '../utils/job_copy.dart';

class JobFormView extends GetView<JobsController> {
  const JobFormView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('New job')),
      body: Obx(() {
        final err = controller.errorMessage.value;
        final useSite = controller.locationMode.value == 'site';
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PageContent(
              width: PageContentWidth.narrow,
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
                controller: controller.titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: controller.kind.value,
                items: [
                  DropdownMenuItem(
                    value: 'standing',
                    child: Text(kindLabel('standing')),
                  ),
                  DropdownMenuItem(
                    value: 'ad_hoc',
                    child: Text(kindLabel('ad_hoc')),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) controller.kind.value = v;
                },
                decoration: const InputDecoration(
                  labelText: 'Kind',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: controller.locationMode.value,
                items: [
                  DropdownMenuItem(
                    value: 'site',
                    child: Text(locationModeLabel('site')),
                  ),
                  DropdownMenuItem(
                    value: 'branch',
                    child: Text(locationModeLabel('branch')),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) {
                    controller.locationMode.value = v;
                    controller.refreshClientSiteWarning();
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'Location mode',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: controller.selectedClientId.value,
                items: [
                  for (final c in controller.clients)
                    DropdownMenuItem(value: c.id, child: Text(c.fullName)),
                ],
                onChanged:
                    controller.isLoadingSites.value
                        ? null
                        : controller.onClientChanged,
                decoration: InputDecoration(
                  labelText:
                      controller.kind.value == 'standing'
                          ? 'Client *'
                          : 'Client (optional)',
                  border: const OutlineInputBorder(),
                ),
              ),
              if (controller.clientSiteWarning.value != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: Text(
                    controller.clientSiteWarning.value!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              ...(useSite
                  ? [
                    DropdownButtonFormField<String>(
                      value: controller.selectedSiteId.value,
                      items: [
                        for (final s in controller.sites)
                          DropdownMenuItem(value: s.id, child: Text(s.name)),
                      ],
                      onChanged:
                          controller.isLoadingSites.value ||
                                  controller.sites.isEmpty
                              ? null
                              : (v) => controller.selectedSiteId.value = v,
                      decoration: InputDecoration(
                        labelText:
                            controller.isLoadingSites.value
                                ? 'Client site * (loading…)'
                                : (controller.sites.isEmpty &&
                                    controller.selectedClientId.value != null)
                                ? 'Client site * (none available)'
                                : 'Client site *',
                        border: const OutlineInputBorder(),
                        suffixIcon:
                            controller.isLoadingSites.value
                                ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                                : null,
                      ),
                    ),
                  ]
                  : [
                    DropdownButtonFormField<String>(
                      value: controller.selectedBranchId.value,
                      items: [
                        for (final b in controller.branches)
                          DropdownMenuItem(value: b.id, child: Text(b.name)),
                      ],
                      onChanged: (v) => controller.selectedBranchId.value = v,
                      decoration: const InputDecoration(
                        labelText: 'Branch *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ]),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: controller.geofenceMode.value,
                items: const [
                  DropdownMenuItem(
                    value: 'informational',
                    child: Text('informational'),
                  ),
                  DropdownMenuItem(value: 'enforced', child: Text('enforced')),
                ],
                onChanged: (v) {
                  if (v != null) controller.geofenceMode.value = v;
                },
                decoration: const InputDecoration(
                  labelText: 'Geofence mode',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller.geofenceRadiusCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Geofence radius (m)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              NdisSupportItemPicker(
                supportItemCode: controller.supportItemCode.value,
                supportItemName: controller.supportItemName.value,
                enabled: !controller.isSaving.value,
                labelText: 'Default NDIS support item (optional)',
                onChanged: ({
                  required String? supportItemCode,
                  required String? supportItemName,
                }) {
                  controller.setCreateSupportItem(
                    supportItemCode: supportItemCode,
                    supportItemName: supportItemName,
                  );
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'Optional default for visits on this job.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 24),
              AsyncElevatedButton(
                onPressed: controller.saveJob,
                isLoading: controller.isSaving.value,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Create'),
              ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}
