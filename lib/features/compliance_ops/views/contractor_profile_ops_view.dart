import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/utils/abn_utils.dart';
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
                    const Text(
                      'Business details',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Form(
                      key: controller.profileFormKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: controller.abnCtrl,
                            decoration: const InputDecoration(
                              labelText: 'ABN',
                              hintText: '11 digits',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(11),
                            ],
                            validator: (v) => AbnUtils.formValidator(v),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: controller.accountNameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Account name (optional)',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: controller.bsbCtrl,
                            decoration: InputDecoration(
                              labelText: 'BSB (optional)',
                              helperText: payment == null
                                  ? null
                                  : 'Saved account ending ${payment.accountNumberMasked}',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: controller.accountNumberCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Account number (optional)',
                              helperText:
                                  'Enter a new number only when updating payment details',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton(
                              onPressed: controller.isSaving.value
                                  ? null
                                  : controller.saveBusinessDetails,
                              child: controller.isSaving.value
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Save business details'),
                            ),
                          ),
                        ],
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
