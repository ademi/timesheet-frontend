import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/async_action.dart';
import '../../compliance_ops/widgets/notification_bell_button.dart';
import '../controllers/staff_payments_controller.dart';

String _fmtDateTime(DateTime dt) {
  final local = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}

String _fmtHours(double hours) {
  final rounded = hours.toStringAsFixed(2);
  if (rounded.endsWith('00')) return hours.toStringAsFixed(0);
  if (rounded.endsWith('0')) return hours.toStringAsFixed(1);
  return rounded;
}

class StaffPaymentsView extends GetView<StaffPaymentsController> {
  const StaffPaymentsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Payments'),
        actions: shellAppBarActions(),
      ),
      body: Obx(() {
        final tab = controller.tabIndex.value;
        final err = controller.errorMessage.value;
        final initialLoad = controller.isLoading.value &&
            controller.batches.isEmpty &&
            controller.unpaidVisits.isEmpty;
        return Column(
          children: [
            PageContent(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (err != null) ...[
                      _ErrorBox(err),
                      const SizedBox(height: 12),
                    ],
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Batches'),
                          selected: tab == 0,
                          onSelected: (_) => controller.tabIndex.value = 0,
                        ),
                        ChoiceChip(
                          label: const Text('Create Batch'),
                          selected: tab == 1,
                          onSelected: (_) => controller.tabIndex.value = 1,
                        ),
                      ],
                    ),
                  ],
                ),
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
          PageContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
            ),
          ),
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
          PageContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
          const Text(
            'Create Payment Batch',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose the pay period, then select the contractors to include. Each contractor will bring in all unpaid completed visits for that period.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => controller.pickPeriod(context),
            icon: const Icon(Icons.date_range_outlined),
            label: Text(
              '${controller.periodRange.value.start.toIso8601String().substring(0, 10)} → ${controller.periodRange.value.end.toIso8601String().substring(0, 10)}',
            ),
          ),
          const SizedBox(height: 12),
          if (controller.contractorCandidates.isNotEmpty)
            TextField(
              controller: controller.contractorFilterCtrl,
              decoration: InputDecoration(
                labelText: 'Filter contractors',
                hintText: 'Search by contractor name or ID',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: controller.contractorFilter.value.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear filter',
                        onPressed: controller.contractorFilterCtrl.clear,
                        icon: const Icon(Icons.clear),
                      ),
              ),
            ),
          if (controller.contractorCandidates.isNotEmpty) const SizedBox(height: 12),
          if (controller.contractorCandidates.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${controller.selectedContractorIds.length} contractors · ${controller.selectedVisitCount} visits · ${_fmtHours(controller.selectedTotalHours)} hours selected',
                    ),
                  ),
                ],
              ),
            ),
          if (controller.contractorCandidates.isNotEmpty) const SizedBox(height: 12),
          if (controller.contractorCandidates.isEmpty)
            const Text('No unpaid completed visits in this period.'),
          if (controller.contractorCandidates.isNotEmpty &&
              controller.filteredContractorCandidates.isEmpty)
            const Text('No contractors match this filter.'),
          for (final contractor in controller.filteredContractorCandidates)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                leading: Checkbox(
                  value: controller.selectedContractorIds.contains(contractor.contractorId),
                  onChanged: controller.canManage
                      ? (_) => controller.toggleContractor(contractor.contractorId)
                      : null,
                ),
                title: Text(contractor.contractorName),
                subtitle: Text(
                  '${contractor.visitCount} visits · ${_fmtHours(contractor.totalHours)} hours\n'
                  '${_fmtDateTime(contractor.firstVisitAt)} to ${_fmtDateTime(contractor.lastVisitAt)}',
                ),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Visits in this contractor group',
                      style: Get.textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final visit in contractor.visits)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(visit.jobTitle ?? visit.tenantName ?? visit.id),
                      subtitle: Text(
                        '${_fmtDateTime(visit.scheduledStart)} · ${_fmtHours(visit.scheduledEnd.difference(visit.scheduledStart).inMinutes / 60)} hours',
                      ),
                    ),
                ],
              ),
            ),
          if (controller.canManage)
            const SizedBox(height: 8),
          if (controller.errorMessage.value != null) ...[
            _ErrorBox(controller.errorMessage.value!),
            const SizedBox(height: 8),
          ],
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
            ),
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
