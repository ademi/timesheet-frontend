import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../controllers/contractor_visits_controller.dart';
import '../services/visit_location_service.dart';

String _fmt(DateTime dt) {
  final l = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
}

class ContractorVisitDetailView extends StatefulWidget {
  const ContractorVisitDetailView({super.key});

  @override
  State<ContractorVisitDetailView> createState() =>
      _ContractorVisitDetailViewState();
}

class _ContractorVisitDetailViewState extends State<ContractorVisitDetailView> {
  @override
  void initState() {
    super.initState();
    final c = Get.find<ContractorVisitsController>();
    c.hydrateFromArgs();
    c.refreshSelected();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ContractorVisitsController>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Visit detail')),
      body: Obx(() {
        final v = controller.selected.value;
        final err = controller.errorMessage.value;
        if (v == null) {
          return const Center(child: Text('Visit not loaded.'));
        }
        final gpsBlocked = controller.isWeb;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (err != null) ...[
              _ErrorBox(err),
              const SizedBox(height: 12),
            ],
            Text(v.jobTitle ?? v.tenantName ?? 'Visit',
                style: Get.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Status: ${v.status}'),
            Text('${_fmt(v.scheduledStart)} → ${_fmt(v.scheduledEnd)}'),
            Text(
              'Geofence: ${v.geofenceMode}'
              '${v.geofenceEnforced ? ' (enforced)' : ''}',
            ),
            if (gpsBlocked) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(VisitLocationService.webBlockedMessage),
              ),
            ],
            const Divider(height: 32),
            Text('Tasks', style: Get.textTheme.titleMedium),
            if (v.tasks.isEmpty) const Text('No tasks.'),
            for (final t in v.tasks)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: t.isDone,
                title: Text(t.title),
                onChanged: controller.isSaving.value ||
                        (!v.isCheckedIn && !v.isScheduled)
                    ? null
                    : (_) => controller.toggleTask(t),
              ),
            const Divider(height: 32),
            Text('Required forms', style: Get.textTheme.titleMedium),
            if (v.formRequirements.isEmpty)
              const Text(
                'No form requirements on this visit payload.',
                style: TextStyle(fontSize: 12),
              ),
            if (v.formRequirements.isNotEmpty) ...[
              const SizedBox(height: 8),
              TextField(
                controller: controller.formNotesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notes (payload)',
                  border: OutlineInputBorder(),
                ),
              ),
              for (final req in v.formRequirements)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(req.name ?? req.formTemplateId),
                  subtitle: Text(req.isRequired ? 'Required' : 'Optional'),
                  trailing: TextButton(
                    onPressed: controller.isSaving.value || !v.isCheckedIn
                        ? null
                        : () => controller.submitForm(req),
                    child: const Text('Submit'),
                  ),
                ),
            ],
            if (v.formSubmissions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Submitted: ${v.formSubmissions.map((s) => s.formTemplateId).join(', ')}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
            const SizedBox(height: 24),
            if (v.isScheduled && controller.canCheckIn)
              ElevatedButton(
                onPressed: (gpsBlocked || controller.isSaving.value)
                    ? null
                    : controller.checkIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Check in'),
              ),
            if (v.isCheckedIn && controller.canComplete) ...[
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: (gpsBlocked || controller.isSaving.value)
                    ? null
                    : controller.complete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Complete'),
              ),
            ],
            if (v.isCompleted)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('This visit is completed.'),
              ),
            if (v.isCancelled)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('This visit was cancelled.'),
              ),
          ],
        );
      }),
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
