import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/utils/external_url.dart';
import '../../../shared/widgets/async_action.dart';
import '../controllers/contractor_visits_controller.dart';
import '../services/visit_location_service.dart';
import '../widgets/visit_schema_form.dart';

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
                  PageContent(
                    width: PageContentWidth.narrow,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  if (v.locationLabel?.isNotEmpty == true ||
                      (v.latitude != null && v.longitude != null)) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () => openMapLocation(
                          latitude: v.latitude,
                          longitude: v.longitude,
                          label: v.locationLabel,
                        ),
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('Open in Maps'),
                      ),
                    ),
                  ],
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
                  if (v.isCheckedIn || v.isCompleted) ...[
                    const Divider(height: 32),
                    Text('Forms', style: Get.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (reqs.isEmpty)
                      const Text(
                        'Contact your coordinator — form not configured.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      )
                    else
                      for (final req in reqs)
                        VisitSchemaForm(
                          requirement: req,
                          canSubmit: v.isCheckedIn,
                          isSubmitting: controller.isSaving.value,
                          isSubmitted:
                              controller.isFormSubmitted(req.formTemplateId),
                          onSubmit: (payload) => controller.submitForm(
                            req,
                            payloadJson: payload,
                          ),
                        ),
                    if (v.formSubmissions.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Submissions on file: ${v.formSubmissions.length}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
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
