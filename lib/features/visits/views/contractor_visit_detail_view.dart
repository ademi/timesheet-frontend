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
        final reqs = controller.effectiveFormRequirements;
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
            Text('Progress form', style: Get.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: controller.formNotesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Progress / shift notes',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            if (reqs.isNotEmpty) ...[
              for (final req in reqs)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(req.name ?? req.formTemplateId),
                  subtitle: Text(
                    controller.submittedTemplateIds.contains(req.formTemplateId)
                        ? 'Submitted ✓'
                        : (req.isRequired ? 'Required' : 'Optional'),
                  ),
                  trailing: TextButton(
                    onPressed: controller.isSaving.value || !v.isCheckedIn
                        ? null
                        : () => controller.submitForm(req),
                    child: const Text('Submit'),
                  ),
                ),
            ] else ...[
              Text(
                controller.catalogLoadFailed.value
                    ? 'Required forms are not returned on this visit yet (API gap). '
                        'Copy the template ID from Staff → Jobs → Form templates '
                        '(UUID under the template name), paste it, then Submit.'
                    : 'No form requirements listed for this visit.',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller.manualTemplateIdCtrl,
                decoration: const InputDecoration(
                  labelText: 'Form template ID',
                  hintText: 'Paste UUID from staff Form templates',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: controller.isSaving.value || !v.isCheckedIn
                    ? null
                    : controller.submitManualForm,
                child: const Text('Submit progress form'),
              ),
            ],
            if (controller.submittedTemplateIds.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Submitted this session: ${controller.submittedTemplateIds.join(', ')}',
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
