import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/profile_photo_editor.dart';
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
        title: const Text('Profile'),
        actions: shellAppBarActions(),
      ),
      body: Obx(() {
        final err = controller.errorMessage.value;
        if (controller.isLoading.value && controller.profile.value == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final payment = controller.profile.value?.paymentDetails;
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
                  if (controller.needsAbnBanner) ...[
                    MaterialBanner(
                      content: const Text(
                        'Add your ABN below so providers can verify and pay you.',
                      ),
                      leading: const Icon(Icons.badge_outlined),
                      backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                      actions: const [SizedBox.shrink()],
                    ),
                    const SizedBox(height: 12),
                  ],
                  Center(
                    child: ProfilePhotoEditor(
                      localBytes: controller.localPhotoBytes.value,
                      networkUrl: controller.photo.value?.downloadUrl,
                      documentId: controller.photo.value?.documentId,
                      isLoading: controller.isPhotoLoading.value,
                      enabled: controller.canUploadPhoto,
                      onChanged: controller.onPhotoPicked,
                      onRemove: controller.photo.value?.hasPhoto == true ||
                              (controller.localPhotoBytes.value?.isNotEmpty ??
                                  false)
                          ? controller.removeProfilePhoto
                          : null,
                    ),
                  ),
                  if (controller.canEditProfile) ...[
                    const Divider(height: 32),
                    ContractorProfileSections(controller: controller),
                    if (payment != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Saved account ending ${payment.accountNumberMasked}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: controller.isSaving.value
                            ? null
                            : controller.saveProfile,
                        child: controller.isSaving.value
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
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.payments_outlined),
                    title: const Text('My payments'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Get.toNamed(AppRoutes.contractorPayments),
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
