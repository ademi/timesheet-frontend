import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_navigator.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/profile_photo_editor.dart';
import '../../visits/widgets/worker_sync_diagnostics_panel.dart';
import '../controllers/contractor_profile_controller.dart';
import '../widgets/contractor_profile_sections.dart';
import '../widgets/notification_bell_button.dart';

class ContractorProfileOpsView extends GetView<ContractorProfileController> {
  const ContractorProfileOpsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Obx(() {
          if (!controller.canEditProfile) return const Text('Profile');
          final i = controller.step.value;
          final label =
              i >= 0 && i < ContractorProfileController.stepLabels.length
                  ? ContractorProfileController.stepLabels[i]
                  : 'Profile';
          return Text(label);
        }),
        actions: shellAppBarActions(),
      ),
      body: Obx(() {
        final err = controller.errorMessage.value;
        if (controller.isLoading.value && controller.profile.value == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final payment = controller.profile.value?.paymentDetails;
        final photoCleared = controller.photoCleared.value;
        final hasLocal =
            controller.localPhotoBytes.value?.isNotEmpty ?? false;
        final hasServerPhoto =
            !photoCleared && controller.photo.value?.hasPhoto == true;
        final showSave =
            controller.canEditProfile || controller.hasPendingPhotoChanges;
        final editing = controller.canEditProfile;
        final step = controller.step.value;
        final isLast = step >= ContractorProfileController.maxStep;
        final busy = controller.isSaving.value;

        final photoEditor = Column(
          children: [
            ProfilePhotoEditor(
              localBytes: controller.localPhotoBytes.value,
              networkUrl:
                  photoCleared
                      ? null
                      : controller.photo.value?.downloadUrl,
              documentId:
                  photoCleared
                      ? null
                      : controller.photo.value?.documentId,
              isLoading:
                  controller.isPhotoLoading.value ||
                  (controller.isSaving.value &&
                      controller.hasPendingPhotoChanges),
              enabled:
                  controller.canUploadPhoto && !controller.isSaving.value,
              onChanged: controller.onPhotoPicked,
              onRemove:
                  hasServerPhoto || hasLocal
                      ? controller.clearPendingPhoto
                      : null,
            ),
            if (controller.canUploadPhoto) ...[
              const SizedBox(height: 8),
              const Text(
                'Photo uploads when you Save profile.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ],
        );

        Widget? paymentHint;
        if (payment != null) {
          paymentHint = Text(
            'Saved account ending ${payment.accountNumberMasked}',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
            ),
          );
        }

        if (!editing) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              PageContent(
                width: PageContentWidth.narrow,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (err != null) ...[
                      _ErrorBanner(message: err),
                      const SizedBox(height: 12),
                    ],
                    photoEditor,
                    if (showSave) ...[
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed: busy ? null : controller.saveProfile,
                          child:
                              busy
                                  ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Text('Save profile'),
                        ),
                      ),
                    ],
                    const Divider(height: 32),
                    const WorkerSyncDiagnosticsPanel(),
                    const SizedBox(height: 8),
                    _PaymentsTile(),
                  ],
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: PageContent(
                width: PageContentWidth.narrow,
                child: _ProfileStepIndicator(
                  step: step,
                  onTap: busy ? null : controller.goToStep,
                ),
              ),
            ),
            if (controller.needsAbnBanner)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: PageContent(
                  width: PageContentWidth.narrow,
                  child: MaterialBanner(
                    content: const Text(
                      'Complete each step, answer the document questions, and '
                      'add your ABN. Upload evidence under Credentials.',
                    ),
                    leading: const Icon(Icons.badge_outlined),
                    backgroundColor: AppColors.primary.withValues(
                      alpha: 0.08,
                    ),
                    actions: const [SizedBox.shrink()],
                  ),
                ),
              ),
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
                          _ErrorBanner(message: err),
                          const SizedBox(height: 12),
                        ],
                        ContractorProfileSections(
                          controller: controller,
                          step: step,
                          photoSlot: step == 0 ? photoEditor : null,
                          paymentHint: step == 2 ? paymentHint : null,
                        ),
                        const Divider(height: 32),
                        const WorkerSyncDiagnosticsPanel(),
                        const SizedBox(height: 8),
                        _PaymentsTile(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: PageContent(
                  width: PageContentWidth.narrow,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        if (step > 0)
                          OutlinedButton(
                            onPressed: busy ? null : controller.previousStep,
                            child: const Text('Back'),
                          ),
                        const Spacer(),
                        if (!isLast) ...[
                          TextButton(
                            onPressed: busy ? null : controller.saveProfile,
                            child: const Text('Save'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: busy ? null : controller.nextStep,
                            child: const Text('Next'),
                          ),
                        ] else
                          FilledButton(
                            onPressed: busy ? null : controller.saveProfile,
                            child:
                                busy
                                    ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Text('Save profile'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: const TextStyle(color: AppColors.error)),
    );
  }
}

class _PaymentsTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.payments_outlined),
      title: const Text('My payments'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => AppNavigator.push(AppRoutes.contractorPayments),
    );
  }
}

class _ProfileStepIndicator extends StatelessWidget {
  const _ProfileStepIndicator({required this.step, this.onTap});

  final int step;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    const labels = ContractorProfileController.stepLabels;
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: InkWell(
              onTap: onTap == null ? null : () => onTap!(i),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color:
                            i <= step ? AppColors.primary : AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9,
                        color:
                            i <= step
                                ? AppColors.textDark
                                : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
