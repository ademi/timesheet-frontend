import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../shared/widgets/async_action.dart';
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
          if (controller.isRefreshing.value) {
            return const Center(child: CircularProgressIndicator());
          }
          return const Center(child: Text('Visit not loaded.'));
        }
        final gpsBlocked = controller.isWeb;
        final reqs = controller.effectiveFormRequirements;
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
                  Text(
                    v.jobTitle ?? v.tenantName ?? 'Visit',
                    style: Get.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text('Status: ${v.status}'),
                  Text('${_fmt(v.scheduledStart)} → ${_fmt(v.scheduledEnd)}'),
                  if (v.locationLabel?.isNotEmpty == true)
                    Text('Location: ${v.locationLabel}'),
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
                      onChanged:
                          controller.isSaving.value ||
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
                        title: Text(req.name ?? 'Progress form'),
                        subtitle: Text(
                          controller.isFormSubmitted(req.formTemplateId)
                              ? 'Submitted ✓'
                              : (req.isRequired ? 'Required' : 'Optional'),
                        ),
                        trailing: TextButton(
                          onPressed:
                              controller.isSaving.value || !v.isCheckedIn
                                  ? null
                                  : () => controller.submitForm(req),
                          child: AsyncButtonChild(
                            isLoading: controller.isSaving.value,
                            child: const Text('Submit'),
                          ),
                        ),
                      ),
                  ] else ...[
                    const Text(
                      'Contact your coordinator — form not configured.',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                  if (v.formSubmissions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Submissions on file: ${v.formSubmissions.length}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (v.isScheduled && controller.canCheckIn)
                    AsyncElevatedButton(
                      onPressed: gpsBlocked ? null : controller.checkIn,
                      isLoading: controller.isSaving.value,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Check in'),
                    ),
                  if (v.isCheckedIn && controller.canComplete) ...[
                    const SizedBox(height: 8),
                    AsyncElevatedButton(
                      onPressed: gpsBlocked ? null : controller.complete,
                      isLoading: controller.isSaving.value,
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
              ),
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
