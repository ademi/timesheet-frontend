import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/controllers/auth_controller.dart';
import '../../../app/themes/app_colors.dart';
import '../../../shared/widgets/async_action.dart';
import '../controllers/staff_payments_controller.dart';

class StaffPaymentsView extends GetView<StaffPaymentsController> {
  const StaffPaymentsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Payments'),
        actions: [
          if (Get.isRegistered<AuthController>())
            IconButton(
              tooltip: 'Log out',
              onPressed: () => Get.find<AuthController>().logout(),
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: Obx(() {
        final tab = controller.tabIndex.value;
        final err = controller.errorMessage.value;
        final initialLoad = controller.isLoading.value &&
            controller.batches.isEmpty &&
            controller.unpaidVisits.isEmpty;
        return Column(
          children: [
            if (err != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: _ErrorBox(err),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Batches'),
                    selected: tab == 0,
                    onSelected: (_) => controller.tabIndex.value = 0,
                  ),
                  ChoiceChip(
                    label: const Text('Create batch'),
                    selected: tab == 1,
                    onSelected: (_) => controller.tabIndex.value = 1,
                  ),
                ],
              ),
            ),
            if (controller.isLoading.value && !initialLoad)
              const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: initialLoad
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: controller.loadAll,
                      child: tab == 0
                          ? _BatchesTab(controller: controller)
                          : _CreateBatchTab(controller: controller),
                    ),
            ),
          ],
        );
      }),
    );
  }
}

class _BatchesTab extends StatelessWidget {
  const _BatchesTab({required this.controller});
  final StaffPaymentsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selected = controller.selectedBatch.value;
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            value: controller.batchStatusFilter.value.isEmpty
                ? null
                : controller.batchStatusFilter.value,
            items: const [
              DropdownMenuItem(value: null, child: Text('All statuses')),
              DropdownMenuItem(value: 'draft', child: Text('draft')),
              DropdownMenuItem(value: 'posted', child: Text('posted')),
              DropdownMenuItem(value: 'void', child: Text('void')),
            ],
            onChanged: controller.setBatchStatusFilter,
            decoration: const InputDecoration(
              labelText: 'Status filter',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (controller.batches.isEmpty) const Text('No payment batches.'),
          for (final b in controller.batches)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(b.periodLabel ?? b.id),
                subtitle: Text(
                  '${b.status} · ${b.totalAmount} ${b.currencyCode}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => controller.openBatch(b),
              ),
            ),
          if (selected != null) ...[
            const Divider(height: 32),
            Text('Batch detail', style: Get.textTheme.titleMedium),
            Text('${selected.status} · ${selected.totalAmount} ${selected.currencyCode}'),
            if (selected.periodLabel != null) Text(selected.periodLabel!),
            const SizedBox(height: 8),
            for (final line in selected.lines)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Visit ${line.visitId} · ${line.hours}h × ${line.rate} = ${line.amount}',
                ),
                subtitle: line.bandBreakdown.isEmpty
                    ? null
                    : Text('band_breakdown: ${line.bandBreakdown}'),
              ),
            if (controller.canManage && selected.isDraft)
              AsyncElevatedButton(
                onPressed: () => controller.postBatch(selected),
                isLoading: controller.isSaving.value,
                child: const Text('Post batch'),
              ),
            if (controller.canManage && selected.isPosted) ...[
              const SizedBox(height: 8),
              AsyncOutlinedButton(
                onPressed: () => controller.voidBatch(selected),
                isLoading: controller.isSaving.value,
                child: const Text('Void batch'),
              ),
            ],
          ],
        ],
      );
    });
  }
}

class _CreateBatchTab extends StatelessWidget {
  const _CreateBatchTab({required this.controller});
  final StaffPaymentsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Select completed unpaid visits, then create a draft batch.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller.periodLabelCtrl,
            decoration: const InputDecoration(
              labelText: 'Period label',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (controller.unpaidVisits.isEmpty)
            const Text('No unpaid completed visits in the last 90 days.'),
          for (final v in controller.unpaidVisits)
            CheckboxListTile(
              value: controller.selectedVisitIds.contains(v.id),
              onChanged: controller.canManage
                  ? (_) => controller.toggleVisit(v.id)
                  : null,
              title: Text(v.jobTitle ?? v.id),
              subtitle: Text(
                '${v.scheduledStart.toLocal()} · ${v.contractorName ?? v.contractorId}',
              ),
            ),
          if (controller.canManage)
            AsyncElevatedButton(
              onPressed: controller.createBatch,
              isLoading: controller.isSaving.value,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Create draft batch'),
            ),
        ],
      );
    });
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: const TextStyle(color: AppColors.error)),
    );
  }
}
