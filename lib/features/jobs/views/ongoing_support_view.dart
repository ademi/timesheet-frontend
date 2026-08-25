import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/async_action.dart';
import '../../../shared/widgets/ndis_support_item_picker.dart';
import '../controllers/ongoing_support_controller.dart';
import '../utils/recurrence_rrule_builder.dart';

class OngoingSupportView extends GetView<OngoingSupportController> {
  const OngoingSupportView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Start ongoing support')),
      body: Obx(() {
        final err = controller.errorMessage.value;
        final blockHome = controller.blocksHomeWithoutSites;
        final multiSlot = controller.requiredSlots.value > 1;
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
            if (blockHome) ...[
              const _AmberNotice(
                message:
                    'Add a site for this client before starting ongoing support.',
              ),
              const SizedBox(height: 12),
            ] else
              DropdownButtonFormField<String>(
                value: controller.selectedSiteId.value,
                items: [
                  for (final site in controller.sites)
                    DropdownMenuItem(value: site.id, child: Text(site.name)),
                ],
                onChanged:
                    controller.sites.isEmpty
                        ? null
                        : (value) => controller.selectedSiteId.value = value,
                decoration: const InputDecoration(
                  labelText: 'Client site *',
                  border: OutlineInputBorder(),
                ),
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<RecurrenceFrequency>(
              value: controller.frequency.value,
              items: [
                for (final value in RecurrenceFrequency.values)
                  DropdownMenuItem(
                    value: value,
                    child: Text(value.name.capitalizeFirst!),
                  ),
              ],
              onChanged: (value) {
                if (value != null) controller.frequency.value = value;
              },
              decoration: const InputDecoration(
                labelText: 'Repeats',
                border: OutlineInputBorder(),
              ),
            ),
            if (controller.requiresWeekdays) ...[
              const SizedBox(height: 12),
              const Text('On days *'),
              Wrap(
                children: [
                  for (var day = DateTime.monday; day <= DateTime.sunday; day++)
                    FilterChip(
                      label: Text(weekdayRruleCodes[day]!),
                      selected: controller.weekdays.contains(day),
                      onSelected: (_) => controller.toggleWeekday(day),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            _DateTile(
              label: 'Start date',
              value: controller.startDate.value,
              onSelected: (date) => controller.startDate.value = date,
            ),
            _DateTile(
              label: 'Ends on',
              value: controller.endDate.value,
              onSelected: (date) => controller.endDate.value = date,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.startTimeCtrl,
              decoration: const InputDecoration(
                labelText: 'Start',
                hintText: '09:00',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.endTimeCtrl,
              decoration: const InputDecoration(
                labelText: 'End',
                hintText: '12:00',
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
                controller.setSupportItem(
                  supportItemCode: supportItemCode,
                  supportItemName: supportItemName,
                );
              },
            ),
            const SizedBox(height: 12),
            const Text(
              'Applies as the job default for generated visits.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: controller.requiredSlots.value,
              items: [
                for (var n = 1; n <= 8; n++)
                  DropdownMenuItem(value: n, child: Text('$n')),
              ],
              onChanged: (value) {
                if (value != null) controller.requiredSlots.value = value;
              },
              decoration: const InputDecoration(
                labelText: 'Needs how many people',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: multiSlot ? null : controller.soleContractorId,
              items: [
                const DropdownMenuItem(value: null, child: Text('Unfilled')),
                if (!multiSlot)
                  for (final engagement in controller.assignableEngagements)
                    DropdownMenuItem(
                      value: engagement.contractorId,
                      child: Text(
                        engagement.contractorName ?? engagement.contractorId,
                      ),
                    ),
              ],
              onChanged: multiSlot ? null : controller.selectSoleContractor,
              decoration: InputDecoration(
                labelText: 'Worker (optional)',
                border: const OutlineInputBorder(),
                helperText:
                    multiSlot
                        ? 'Assign workers from the roster when multiple slots are needed'
                        : null,
              ),
            ),
            const SizedBox(height: 24),
            AsyncElevatedButton(
              onPressed: blockHome ? null : controller.submit,
              isLoading: controller.isSaving.value,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Save and fill roster'),
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

class _AmberNotice extends StatelessWidget {
  const _AmberNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.openSlotBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.openSlot),
      ),
      child: Text(
        message,
        style: const TextStyle(fontSize: 13, color: AppColors.openSlot),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.value,
    required this.onSelected,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: Text(MaterialLocalizations.of(context).formatMediumDate(value)),
    trailing: const Icon(Icons.calendar_today),
    onTap: () async {
      final picked = await showDatePicker(
        context: context,
        initialDate: value,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );
      if (picked != null) onSelected(picked);
    },
  );
}
