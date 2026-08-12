import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../shared/widgets/async_action.dart';
import '../controllers/staff_visits_controller.dart';

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
                  const Divider(height: 32),
                  Text('Tasks', style: Get.textTheme.titleMedium),
                  if (v.tasks.isEmpty) const Text('No tasks.'),
                  for (final t in v.tasks)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        t.isDone
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: t.isDone ? AppColors.primary : null,
                      ),
                      title: Text(t.title),
                    ),
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
