import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../shared/widgets/async_action.dart';
import '../controllers/jobs_controller.dart';

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
              controller: controller.titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Title *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: controller.kind.value,
              items: const [
                DropdownMenuItem(value: 'standing', child: Text('standing')),
                DropdownMenuItem(value: 'ad_hoc', child: Text('ad_hoc')),
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
              items: const [
                DropdownMenuItem(
                  value: 'site',
                  child: Text('Client site (XOR)'),
                ),
                DropdownMenuItem(
                  value: 'branch',
                  child: Text('Branch (XOR)'),
                ),
              ],
              onChanged: (v) {
                if (v != null) controller.locationMode.value = v;
              },
              decoration: const InputDecoration(
                labelText: 'Location mode',
                border: OutlineInputBorder(),
                helperText: 'Exactly one of client_site_id or branch_id',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: controller.selectedClientId.value,
              items: [
                for (final c in controller.clients)
                  DropdownMenuItem(value: c.id, child: Text(c.fullName)),
              ],
              onChanged: controller.isLoadingSites.value
                  ? null
                  : controller.onClientChanged,
              decoration: InputDecoration(
                labelText: controller.kind.value == 'standing'
                    ? 'Client * (standing)'
                    : 'Client (optional)',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (useSite)
              DropdownButtonFormField<String>(
                value: controller.selectedSiteId.value,
                items: [
                  for (final s in controller.sites)
                    DropdownMenuItem(value: s.id, child: Text(s.name)),
                ],
                onChanged: controller.isLoadingSites.value
                    ? null
                    : (v) => controller.selectedSiteId.value = v,
                decoration: InputDecoration(
                  labelText: controller.isLoadingSites.value
                      ? 'Client site * (loading…)'
                      : 'Client site *',
                  border: const OutlineInputBorder(),
                  suffixIcon: controller.isLoadingSites.value
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
              )
            else
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
        );
      }),
    );
  }
}
