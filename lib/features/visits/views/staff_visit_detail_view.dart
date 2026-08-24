import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../billing/data/models/billing_models.dart';
import '../../../shared/widgets/async_action.dart';
import '../../../shared/widgets/ndis_support_item_picker.dart';
import '../controllers/staff_visits_controller.dart';
import '../data/models/visit_models.dart';

String _fmt(DateTime dt) {
  final l = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
}

class StaffVisitDetailView extends StatefulWidget {
  const StaffVisitDetailView({super.key});

  @override
  State<StaffVisitDetailView> createState() => _StaffVisitDetailViewState();
}

class _StaffVisitDetailViewState extends State<StaffVisitDetailView> {
  @override
  void initState() {
    super.initState();
    final c = Get.find<StaffVisitsController>();
    c.applyRouteArgs();
    c.hydrateFromArgs();
    c.refreshSelected();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<StaffVisitsController>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Visit')),
      body: Obx(() {
        final v = controller.selected.value;
        final err = controller.errorMessage.value;
        if (v == null) {
          if (controller.isRefreshing.value) {
            return const Center(child: CircularProgressIndicator());
          }
          return const Center(child: Text('Visit not loaded.'));
        }
        return Column(
          children: [
            if (controller.isRefreshing.value)
              const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  PageContent(
                    width: PageContentWidth.narrow,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (err != null) ...[
                          _ErrorBox(err),
                          const SizedBox(height: 12),
                        ],
                        Text(v.jobTitle ?? 'Visit', style: Get.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text('Status: ${v.status} · payment: ${v.paymentStatus}'),
                        Text('Start: ${_fmt(v.scheduledStart)}'),
                        Text('End: ${_fmt(v.scheduledEnd)}'),
                        if (v.locationLabel?.isNotEmpty == true)
                          Text('Location: ${v.locationLabel}'),
                        Text(
                          'Geofence: ${v.geofenceMode} / ${v.geofenceRadiusM}m'
                          '${v.latitude != null ? ' @ ${v.latitude}, ${v.longitude}' : ''}',
                        ),
                        if (v.contractorName?.isNotEmpty == true)
                          Text('Contractor: ${v.contractorName}'),
                        Obx(() {
                          final ndis = controller.participantNdisNumber.value;
                          if (ndis == null && !controller.isLoadingParticipantNdis.value) {
                            return const SizedBox.shrink();
                          }
                          if (controller.isLoadingParticipantNdis.value &&
                              ndis == null) {
                            return const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Text(
                                'Loading participant NDIS…',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            );
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              ndis != null && ndis.isNotEmpty
                                  ? 'NDIS $ndis'
                                  : 'NDIS —',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textMuted,
                              ),
                            ),
                          );
                        }),
                        const Divider(height: 32),
                        Text('NDIS support item', style: Get.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        if (controller.canEditVisitSupportItem)
                          NdisSupportItemPicker(
                            supportItemCode:
                                controller.editingVisitSupportItemCode.value,
                            supportItemName:
                                controller.editingVisitSupportItemName.value,
                            enabled: !controller.isSaving.value,
                            labelText: 'Visit-level NDIS item',
                            onChanged: ({
                              required String? supportItemCode,
                              required String? supportItemName,
                            }) {
                              controller.updateVisitSupportItem(
                                supportItemCode: supportItemCode,
                                supportItemName: supportItemName,
                              );
                            },
                          )
                        else if (v.supportItemCode != null &&
                            v.supportItemName != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(v.supportItemName!),
                              Text(
                                v.supportItemCode!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          )
                        else if (v.supportItemCode != null)
                          Text(
                            v.supportItemCode!,
                            style: const TextStyle(color: AppColors.textMuted),
                          )
                        else
                          const Text(
                            'None set.',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          controller.canEditVisitSupportItem
                              ? 'Editable while scheduled and unpaid.'
                              : 'Locked after check-in or payment.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const Divider(height: 32),
                        Text('Price tier', style: Get.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        if (controller.canEditVisitPriceTier)
                          DropdownButtonFormField<String?>(
                            value: controller.editingPriceTierOverride.value,
                            decoration: const InputDecoration(
                              labelText: 'Price tier override',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Auto (MMM postcode)'),
                              ),
                              DropdownMenuItem<String?>(
                                value: PriceTier.national,
                                child: Text('National'),
                              ),
                              DropdownMenuItem<String?>(
                                value: PriceTier.remote,
                                child: Text('Remote'),
                              ),
                              DropdownMenuItem<String?>(
                                value: PriceTier.veryRemote,
                                child: Text('Very remote'),
                              ),
                            ],
                            onChanged: controller.isSaving.value
                                ? null
                                : controller.updateVisitPriceTier,
                          )
                        else
                          Text(
                            PriceTier.labelForOverride(v.priceTierOverride),
                            style: TextStyle(
                              color: controller.priceTierEditBlocked.value
                                  ? AppColors.textMuted
                                  : null,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          controller.priceTierEditBlocked.value
                              ? 'Locked — already included in an export.'
                              : 'Staff override wins over MMM postcode. Without an override, export still needs a job location postcode.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const Divider(height: 32),
                        Text('Shift tasks', style: Get.textTheme.titleMedium),
                        if (controller.hasCodedTasks) ...[
                          const SizedBox(height: 4),
                          const Text(
                            'Tasks with NDIS codes export as separate invoice lines (multi-line mode).',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                        if (controller.taskMinutesExceedVisitWarning) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.errorBackground,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Task minutes total (${controller.codedTaskMinutesTotal}) '
                              'exceeds visit duration (${controller.visitScheduledMinutes} min). '
                              'Export will fail until adjusted.',
                              style: const TextStyle(color: AppColors.error),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        if (v.tasks.isEmpty) const Text('No tasks.'),
                        for (final t in v.tasks)
                          _VisitTaskRow(controller: controller, task: t),
                        if (controller.canManage &&
                            !v.isCancelled &&
                            !v.isCompleted) ...[
                          const Divider(height: 32),
                          AsyncElevatedButton(
                            onPressed: () => _reschedule(context, controller),
                            isLoading: controller.isSaving.value,
                            child: const Text('Reschedule…'),
                          ),
                          const SizedBox(height: 8),
                          AsyncOutlinedButton(
                            onPressed: controller.cancelSelected,
                            isLoading: controller.isSaving.value,
                            child: const Text('Cancel visit'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _reschedule(
    BuildContext context,
    StaffVisitsController controller,
  ) async {
    final v = controller.selected.value;
    if (v == null) return;

    final current = v.scheduledStart.toLocal();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null || !context.mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
      helpText: 'Start time',
    );
    if (pickedTime == null || !context.mounted) return;

    final duration = v.scheduledEnd.difference(v.scheduledStart);
    final newStart = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    final newEnd = newStart.add(duration);

    await controller.rescheduleSelected(start: newStart, end: newEnd);
  }
}

class _VisitTaskRow extends StatelessWidget {
  const _VisitTaskRow({
    required this.controller,
    required this.task,
  });

  final StaffVisitsController controller;
  final VisitTaskOut task;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final code =
          controller.taskSupportPickerCode(task) ?? task.supportItemCode;
      final name = controller.taskSupportPickerName(task);
      final hasSupportItemCode = code?.trim().isNotEmpty == true;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              task.isDone ? Icons.check_circle : Icons.radio_button_unchecked,
              color: task.isDone ? AppColors.primary : null,
            ),
            title: Text(task.title),
          ),
          if (controller.canEditVisitSupportItem)
            Padding(
              padding: const EdgeInsets.only(left: 40, bottom: 12),
              child: NdisSupportItemPicker(
                supportItemCode: code,
                supportItemName: name,
                enabled: !controller.isSaving.value,
                labelText: 'Task NDIS item (optional)',
                onChanged: ({
                  required String? supportItemCode,
                  required String? supportItemName,
                }) {
                  controller.updateVisitTaskSupportItem(
                    task: task,
                    supportItemCode: supportItemCode,
                    supportItemName: supportItemName,
                  );
                },
              ),
            )
          else if (task.supportItemCode != null)
            Padding(
              padding: const EdgeInsets.only(left: 40, bottom: 12),
              child: Text(
                task.supportItemCode!,
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
          if (hasSupportItemCode && controller.canEditVisitTaskBilling)
            Padding(
              padding: const EdgeInsets.only(left: 40, bottom: 12),
              child: _BillableMinutesField(
                key: ValueKey(
                  '${task.id}-${controller.taskBillableMinutesDisplay(task)}',
                ),
                initialMinutes: controller.taskBillableMinutesDisplay(task),
                enabled: !controller.isSaving.value,
                onSubmitted: (value) =>
                    controller.updateVisitTaskBillableMinutes(
                  task: task,
                  rawMinutes: value,
                ),
              ),
            )
          else if (hasSupportItemCode && task.billableMinutes != null)
            Padding(
              padding: const EdgeInsets.only(left: 40, bottom: 12),
              child: Text(
                '${task.billableMinutes} billable min',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
        ],
      );
    });
  }
}

class _BillableMinutesField extends StatefulWidget {
  const _BillableMinutesField({
    super.key,
    required this.initialMinutes,
    required this.enabled,
    required this.onSubmitted,
  });

  final int? initialMinutes;
  final bool enabled;
  final ValueChanged<String> onSubmitted;

  @override
  State<_BillableMinutesField> createState() => _BillableMinutesFieldState();
}

class _BillableMinutesFieldState extends State<_BillableMinutesField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.initialMinutes?.toString() ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant _BillableMinutesField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialMinutes != widget.initialMinutes) {
      _ctrl.text = widget.initialMinutes?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _ctrl,
      enabled: widget.enabled,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        labelText: 'Billable minutes',
        helperText: '0–1440 · press Enter to save',
        border: OutlineInputBorder(),
      ),
      onFieldSubmitted: widget.onSubmitted,
    );
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
