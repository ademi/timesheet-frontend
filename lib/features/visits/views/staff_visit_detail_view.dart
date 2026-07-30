import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
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
          return const Center(child: Text('Visit not loaded.'));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (err != null) ...[_ErrorBox(err), const SizedBox(height: 12)],
            Text(v.jobTitle ?? 'Visit', style: Get.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Status: ${v.status} · payment: ${v.paymentStatus}'),
            Text('Start: ${_fmt(v.scheduledStart)}'),
            Text('End: ${_fmt(v.scheduledEnd)}'),
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
                  t.isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: t.isDone ? AppColors.primary : null,
                ),
                title: Text(t.title),
              ),
            if (controller.canManage && !v.isCancelled && !v.isCompleted) ...[
              const Divider(height: 32),
              ElevatedButton(
                onPressed:
                    controller.isSaving.value
                        ? null
                        : () => _reschedule(controller),
                child: const Text('Reschedule (+1 hour)'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed:
                    controller.isSaving.value
                        ? null
                        : controller.cancelSelected,
                child: const Text('Cancel visit'),
              ),
            ],
          ],
        );
      }),
    );
  }

  Future<void> _reschedule(StaffVisitsController controller) async {
    final v = controller.selected.value;
    if (v == null) return;
    final start = v.scheduledStart.add(const Duration(hours: 1));
    final end = v.scheduledEnd.add(const Duration(hours: 1));
    await controller.rescheduleSelected(start: start, end: end);
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
