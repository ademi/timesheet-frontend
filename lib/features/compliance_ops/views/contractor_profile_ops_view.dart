import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/profile_photo_editor.dart';
import '../controllers/contractor_profile_controller.dart';
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
                child: Text(err, style: const TextStyle(color: AppColors.error)),
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
                        (controller.localPhotoBytes.value?.isNotEmpty ?? false)
                    ? controller.removeProfilePhoto
                    : null,
              ),
            ),
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
